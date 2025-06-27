require "test_helper"

class IssueCorrelationServiceTest < ActiveSupport::TestCase
  setup do
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)

    # Ensure GitHub token is set for tests
    @original_token = ENV["GHTA_GITHUB_TOKEN"]
    ENV["GHTA_GITHUB_TOKEN"] = "ghp_test_token_for_testing"
  end

  teardown do
    # Restore original token
    if @original_token
      ENV["GHTA_GITHUB_TOKEN"] = @original_token
    else
      ENV.delete("GHTA_GITHUB_TOKEN")
    end
  end

  test "service initializes with correct parameters" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "department-of-veterans-affairs/va.gov-team"
    )

    assert_equal @team, service.team
    assert_equal "access", service.search_terms
    assert_equal "test", service.exclusion_terms
    assert_equal "department-of-veterans-affairs/va.gov-team", service.repository
  end

  test "service initializes with exclusion_terms converted to lowercase" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "TEST_TERMS",
      repository: "test/repo"
    )

    assert_equal "test_terms", service.exclusion_terms
  end

  test "map_issue_status converts GitHub states correctly" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    assert_equal "open", service.send(:map_issue_status, "open")
    assert_equal "resolved", service.send(:map_issue_status, "closed")
    assert_equal "open", service.send(:map_issue_status, "unknown")
    assert_equal "open", service.send(:map_issue_status, nil)
  end

  test "truncate_description limits description length" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    long_text = "A" * 1500

    result = service.send(:truncate_description, long_text)
    assert_equal 1000, result.length
    assert result.ends_with?("...")

    # Test with nil and blank
    assert_nil service.send(:truncate_description, nil)
    assert_nil service.send(:truncate_description, "")
  end

  test "find_correlations_for_team processes members with batch results" do
    # Create a mock GraphQL client that returns test data
    mock_client = Object.new

    # Mock the batch search to return some test issues
    def mock_client.batch_search_issues_for_members(team_members, search_terms:, repository:, exclusion_terms:)
      # Return issues for the first member found
      first_member = team_members.first
      return {} unless first_member

      {
        first_member.github_login => [
          {
            github_issue_number: 123,
            github_issue_url: "https://github.com/test/repo/issues/123",
            title: "Test Issue",
            body: "Test body",
            state: "open",
            created_at: Time.current,
            updated_at: Time.current
          }
        ]
      }
    end

    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    # Replace the graphql_client instance variable with our mock
    service.instance_variable_set(:@graphql_client, mock_client)

    # Execute the batch processing
    assert_nothing_raised do
      service.find_correlations_for_team
    end
  end

  test "update_correlations_for_member with empty issues removes all correlations" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    # Create an existing correlation first
    existing = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 999,
      github_issue_url: "https://github.com/test/repo/issues/999",
      title: "Old Issue",
      status: "open"
    )

    # Call with empty issues array
    service.send(:update_correlations_for_member, @team_member, [])

    # Should remove the existing correlation
    assert_not IssueCorrelation.exists?(existing.id)
  end

  test "update_correlations_for_member with issues creates and removes appropriately" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    # Create an existing correlation that should be removed
    old_correlation = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 888,
      github_issue_url: "https://github.com/test/repo/issues/888",
      title: "Old Issue",
      status: "open"
    )

    # Provide new issues that don't include the old one
    new_issues = [
      {
        github_issue_number: 456,
        github_issue_url: "https://github.com/test/repo/issues/456",
        title: "New Issue",
        body: "New body",
        state: "open",
        created_at: Time.current,
        updated_at: Time.current
      }
    ]

    # Call the method
    service.send(:update_correlations_for_member, @team_member, new_issues)

    # Should remove old correlation and create new one
    assert_not IssueCorrelation.exists?(old_correlation.id)
    new_correlation = IssueCorrelation.find_by(team_member: @team_member, github_issue_number: 456)
    assert_not_nil new_correlation
    assert_equal "New Issue", new_correlation.title
  end

  test "update_correlations_for_member removes old correlations" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    # Create an existing correlation
    existing_correlation = IssueCorrelation.create!(
      team_member: @team_member,
      github_issue_number: 999,
      github_issue_url: "https://github.com/test/repo/issues/999",
      title: "Old Issue",
      status: "open"
    )

    # Call with empty issues array (should remove all correlations)
    service.send(:update_correlations_for_member, @team_member, [])

    # Verify the old correlation was removed
    assert_not IssueCorrelation.exists?(existing_correlation.id)
  end

  test "broadcast_member_issues_update sends turbo stream" do
    service = IssueCorrelationService.new(
      @team,
      search_terms: "access",
      exclusion_terms: "test",
      repository: "test/repo"
    )

    # Track broadcast calls
    broadcast_calls = []
    original_method = Turbo::StreamsChannel.method(:broadcast_replace_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |*args|
      broadcast_calls << args
    end

    begin
      # Call the private method
      service.send(:broadcast_member_issues_update, @team_member)

      # Verify broadcast was called
      assert_equal 1, broadcast_calls.length
      assert_equal "team_#{@team.id}", broadcast_calls[0][0]
      assert_equal "member-issues-#{@team_member.id}", broadcast_calls[0][1][:target]
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_method)
    end
  end
end
