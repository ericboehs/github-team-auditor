require "test_helper"

class IssueCorrelationServiceTest < ActiveSupport::TestCase
  setup do
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)

    # Create a simple stub API client
    @api_client = Object.new
    def @api_client.search_issues(query, repository:)
      []
    end

    @service = IssueCorrelationService.new(
      @team,
      api_client: @api_client,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "department-of-veterans-affairs/va.gov-team"
    )
  end

  test "service initializes with correct parameters" do
    assert_equal @team, @service.team
    assert_equal @api_client, @service.api_client
    assert_equal "access", @service.search_terms
    assert_equal "test", @service.exclusion_terms
    assert_equal "department-of-veterans-affairs/va.gov-team", @service.repository
  end

  test "service initializes with exclusion_terms converted to lowercase" do
    service = IssueCorrelationService.new(
      @team,
      api_client: @api_client,
      search_terms: "access",
      exclusion_terms: "TEST_TERMS",
      repository: "test/repo"
    )

    assert_equal "test_terms", service.exclusion_terms
  end

  test "find_correlations_for_member executes full workflow" do
    # Set up API client to return mock issues
    issues = [
      {
        github_issue_number: 123,
        github_issue_url: "https://github.com/test/repo/issues/123",
        title: "Test issue",
        body: "Test body",
        state: "open",
        created_at: Time.current,
        updated_at: Time.current
      }
    ]

    # Override API client method
    @api_client.define_singleton_method(:search_issues) { |*args| issues }

    log_output = StringIO.new
    Rails.logger.stub(:debug, proc { |msg| log_output.puts(msg) }) do
      # Override broadcast method to avoid errors during update
      @service.define_singleton_method(:broadcast_member_issues_update) { |member| }

      result = @service.find_correlations_for_member(@team_member)

      # The result should be the filtered issues (excluding test issues)
      # Since our service has exclusion_terms: "test", the "Test issue" will be filtered out
      assert_equal 0, result.length, "Issues with 'test' in title should be filtered out"
    end

    assert_includes log_output.string, "Finding issue correlations for #{@team_member.github_login}"
    assert_includes log_output.string, "Found 0 issue correlations for #{@team_member.github_login}"
  end

  test "find_correlations_for_member filters excluded issues" do
    issues = [
      { title: "Regular issue", github_issue_number: 1 },
      { title: "Test issue to exclude", github_issue_number: 2 }
    ]

    # Override API client method
    @api_client.define_singleton_method(:search_issues) { |*args| issues }

    # Create a service that tracks update calls
    update_calls = []
    @service.define_singleton_method(:update_correlations_for_member) do |member, filtered_issues|
      update_calls << [ member, filtered_issues ]
    end

    result = @service.find_correlations_for_member(@team_member)

    assert_equal 1, result.length
    assert_equal "Regular issue", result[0][:title]
    assert_equal 1, update_calls.length
    assert_equal 1, update_calls[0][1].length
    assert_equal "Regular issue", update_calls[0][1][0][:title]
  end

  test "sanitize_search_term removes dangerous characters and limits length" do
    # Test basic sanitization
    result = @service.send(:sanitize_search_term, "test & <script>")
    assert_equal "test  script", result

    # Test length limiting
    long_term = "a" * 150
    result = @service.send(:sanitize_search_term, long_term)
    assert_equal 100, result.length

    # Test blank input
    result = @service.send(:sanitize_search_term, "")
    assert_equal "", result

    # Test nil input
    result = @service.send(:sanitize_search_term, nil)
    assert_equal "", result
  end

  test "filter_excluded_issues removes issues with exclusion terms in title" do
    issues = [
      { title: "Regular issue" },
      { title: "Test issue to exclude" },
      { title: "Another normal issue" }
    ]

    result = @service.send(:filter_excluded_issues, issues)

    assert_equal 2, result.length
    assert_equal "Regular issue", result[0][:title]
    assert_equal "Another normal issue", result[1][:title]
  end

  test "filter_excluded_issues returns all issues when exclusion_terms is blank" do
    service = IssueCorrelationService.new(
      @team,
      api_client: @api_client,
      search_terms: "access",
      exclusion_terms: "",
      repository: "test/repo"
    )

    issues = [
      { title: "Regular issue" },
      { title: "Test issue" }
    ]

    result = service.send(:filter_excluded_issues, issues)

    assert_equal 2, result.length
  end

  test "map_issue_status converts GitHub states correctly" do
    assert_equal "open", @service.send(:map_issue_status, "open")
    assert_equal "resolved", @service.send(:map_issue_status, "closed")
    assert_equal "open", @service.send(:map_issue_status, "unknown")
    assert_equal "open", @service.send(:map_issue_status, "OPEN")
    assert_equal "resolved", @service.send(:map_issue_status, "CLOSED")
  end

  test "truncate_description limits description length" do
    long_body = "a" * 1500
    result = @service.send(:truncate_description, long_body)
    assert_equal 1000, result.length

    # Test nil input
    result = @service.send(:truncate_description, nil)
    assert_nil result

    # Test blank input
    result = @service.send(:truncate_description, "")
    assert_nil result
  end

  test "build_search_query includes login and search terms" do
    query = @service.send(:build_search_query, "john_doe")

    assert_includes query, "john_doe"
    assert_includes query, "access"
    assert_includes query, "is:issue"
  end

  test "build_search_query sanitizes inputs" do
    query = @service.send(:build_search_query, "user<script>")

    # Should not contain the script tag
    refute_includes query, "<script>"
    # Should contain sanitized version
    assert_includes query, "userscript"
  end

  test "update_correlations_for_member creates new correlations" do
    issues = [
      {
        github_issue_number: 123,
        github_issue_url: "https://github.com/test/repo/issues/123",
        title: "Test issue",
        body: "Test body",
        state: "open",
        created_at: Time.current,
        updated_at: Time.current
      }
    ]

    # Track upsert calls
    upsert_calls = []
    IssueCorrelation.stub(:upsert_all, proc { |data, options| upsert_calls << [ data, options ] }) do
      # Track transaction calls
      transaction_called = false
      ApplicationRecord.stub(:transaction, proc { |&block| transaction_called = true; block.call }) do
        # Track broadcast calls
        broadcast_calls = []
        @service.define_singleton_method(:broadcast_member_issues_update) do |member|
          broadcast_calls << member
        end

        @service.send(:update_correlations_for_member, @team_member, issues)

        assert transaction_called, "Transaction should be called"
        assert_equal 1, upsert_calls.length
        assert_equal [ :team_member_id, :github_issue_number ], upsert_calls[0][1][:unique_by]
        assert_equal 1, broadcast_calls.length
        assert_equal @team_member, broadcast_calls[0]
      end
    end
  end

  test "update_correlations_for_member removes old correlations when issues exist" do
    issues = [
      {
        github_issue_number: 123,
        github_issue_url: "https://github.com/test/repo/issues/123",
        title: "Test issue",
        body: "Test body",
        state: "open",
        created_at: Time.current,
        updated_at: Time.current
      }
    ]

    # Create a correlation that should be removed
    old_correlation = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 999,
      github_issue_url: "https://github.com/test/repo/issues/999",
      title: "Old issue",
      status: "open"
    )

    assert_difference -> { IssueCorrelation.count }, -1 do
      @service.send(:update_correlations_for_member, @team_member, issues)
    end

    # Verify the old correlation was removed
    assert_not IssueCorrelation.exists?(old_correlation.id)
  end

  test "update_correlations_for_member removes all correlations when no issues found" do
    issues = []

    # Create a correlation that should be removed
    old_correlation = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 999,
      github_issue_url: "https://github.com/test/repo/issues/999",
      title: "Old issue",
      status: "open"
    )

    # Check how many correlations exist before
    initial_count = IssueCorrelation.count
    member_initial_count = @team_member.issue_correlations.count

    @service.send(:update_correlations_for_member, @team_member, issues)

    # Verify all correlations for this member were removed
    assert_equal 0, @team_member.issue_correlations.count
    # The total count should decrease by the number of correlations this member had
    assert_equal initial_count - member_initial_count, IssueCorrelation.count
  end

  test "update_correlations_for_member preserves existing created_at timestamps" do
    current_time = Time.current
    old_time = 1.day.ago

    # Create an existing correlation
    existing_correlation = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Existing issue",
      status: "open",
      created_at: old_time
    )

    issues = [
      {
        github_issue_number: 123,
        github_issue_url: "https://github.com/test/repo/issues/123",
        title: "Updated issue",
        body: "Test body",
        state: "open",
        created_at: current_time,
        updated_at: current_time
      }
    ]

    @service.send(:update_correlations_for_member, @team_member, issues)

    # Reload and verify created_at was preserved
    updated_correlation = IssueCorrelation.find_by(github_issue_number: 123)
    assert_equal old_time.to_i, updated_correlation.created_at.to_i
    assert_equal "Updated issue", updated_correlation.title
  end

  test "broadcast_member_issues_update broadcasts turbo stream" do
    broadcast_calls = []
    Turbo::StreamsChannel.stub(:broadcast_replace_to, proc { |*args| broadcast_calls << args }) do
      @service.send(:broadcast_member_issues_update, @team_member)
    end

    assert_equal 1, broadcast_calls.length
    assert_equal "team_#{@team.id}", broadcast_calls[0][0]
    assert_equal "member-issues-#{@team_member.id}", broadcast_calls[0][1][:target]
    assert_equal "teams/member_issues", broadcast_calls[0][1][:partial]
    assert_equal @team_member, broadcast_calls[0][1][:locals][:member]
  end
end
