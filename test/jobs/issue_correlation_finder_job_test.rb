require "test_helper"

class IssueCorrelationFinderJobTest < ActiveJob::TestCase
  def setup
    @organization = organizations(:va)
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)
  end

  test "should map issue status correctly" do
    job = IssueCorrelationFinderJob.new

    assert_equal "open", job.send(:map_issue_status, "open")
    assert_equal "resolved", job.send(:map_issue_status, "closed")
    assert_equal "open", job.send(:map_issue_status, "unknown")
  end

  test "should truncate long descriptions" do
    job = IssueCorrelationFinderJob.new
    long_body = "x" * 1500

    result = job.send(:truncate_description, long_body)
    assert_equal 1000, result.length
    assert result.end_with?("...")
  end

  test "should handle nil or blank descriptions" do
    job = IssueCorrelationFinderJob.new

    assert_nil job.send(:truncate_description, nil)
    assert_nil job.send(:truncate_description, "")
    assert_nil job.send(:truncate_description, "   ")
  end

  test "should build search query correctly" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@search_terms, "platform access")

    result = job.send(:build_search_query, "john_doe")
    assert_equal "is:issue \"john_doe\" in:body \"john_doe\" in:title \"platform access\"", result
  end

  test "should filter excluded issues" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@exclusion_terms, "temporary")

    issues = [
      { title: "Platform access for john" },
      { title: "Temporary platform access for john" }
    ]

    filtered = job.send(:filter_excluded_issues, issues)
    assert_equal 1, filtered.count
    assert_equal "Platform access for john", filtered.first[:title]
  end

  test "should handle empty exclusion terms" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@exclusion_terms, "")

    issues = [ { title: "Some issue" } ]
    filtered = job.send(:filter_excluded_issues, issues)
    assert_equal 1, filtered.count
  end

  test "should use team effective methods for configuration" do
    @team.update!(
      search_terms: "custom search",
      exclusion_terms: "exclude this",
      search_repository: "custom/repo"
    )

    # Test that job picks up team configuration
    job = IssueCorrelationFinderJob.new

    # Set up the job's instance variables manually to test configuration pickup
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@organization, @team.organization)
    job.instance_variable_set(:@search_terms, @team.effective_search_terms)
    job.instance_variable_set(:@exclusion_terms, @team.effective_exclusion_terms.to_s.downcase)
    job.instance_variable_set(:@repository, @team.effective_search_repository)

    # Verify the instance variables were set from team config
    assert_equal "custom search", job.instance_variable_get(:@search_terms)
    assert_equal "exclude this", job.instance_variable_get(:@exclusion_terms)
    assert_equal "custom/repo", job.instance_variable_get(:@repository)
  end

  test "should use defaults when team config is blank" do
    @team.update!(search_terms: nil, exclusion_terms: nil, search_repository: nil)

    job = IssueCorrelationFinderJob.new

    # Set up the job's instance variables manually to test configuration pickup
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@organization, @team.organization)
    job.instance_variable_set(:@search_terms, @team.effective_search_terms)
    job.instance_variable_set(:@exclusion_terms, @team.effective_exclusion_terms.to_s.downcase)
    job.instance_variable_set(:@repository, @team.effective_search_repository)

    # Should use effective defaults
    assert_equal "access", job.instance_variable_get(:@search_terms)
    assert_equal "", job.instance_variable_get(:@exclusion_terms)
    assert_equal "department-of-veterans-affairs/va.gov-team", job.instance_variable_get(:@repository)
  end

  test "should handle perform method with mocked API client" do
    # Create a team member for testing
    @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    job = IssueCorrelationFinderJob.new

    # Mock the API client and its methods
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      [
        {
          github_issue_number: 123,
          github_issue_url: "https://github.com/test/repo/issues/123",
          title: "Test issue",
          body: "Issue description",
          state: "open",
          created_at: 1.day.ago,
          updated_at: 1.hour.ago
        }
      ]
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)

    assert_nothing_raised do
      job.perform(@team.id)
    end

    # Verify issue correlation was created
    correlation = @team.team_members.first.issue_correlations.first
    assert_not_nil correlation
    assert_equal 123, correlation.github_issue_number
    assert_equal "Test issue", correlation.title
    assert_equal "open", correlation.status
  end

  test "should handle API errors gracefully" do
    # Clear existing team members and create a fresh one for testing
    @team.team_members.destroy_all
    team_member = @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    job = IssueCorrelationFinderJob.new

    # Mock API client that throws an error
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      raise StandardError.new("API Error")
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)

    # Should not raise an error - errors are caught and logged
    assert_nothing_raised do
      job.perform(@team.id)
    end

    # Should not have created any correlations due to error
    assert_equal 0, team_member.issue_correlations.count
  end

  test "should update existing correlations" do
    team_member = @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    # Create existing correlation
    existing_correlation = team_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Old title",
      status: "open",
      issue_created_at: 2.days.ago,
      issue_updated_at: 2.days.ago
    )

    job = IssueCorrelationFinderJob.new

    # Mock API client that returns updated issue data
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      [
        {
          github_issue_number: 123,
          github_issue_url: "https://github.com/test/repo/issues/123",
          title: "Updated title",
          body: "Updated description",
          state: "closed",
          created_at: 2.days.ago,
          updated_at: 1.hour.ago
        }
      ]
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)
    job.perform(@team.id)

    # Verify correlation was updated
    existing_correlation.reload
    assert_equal "Updated title", existing_correlation.title
    assert_equal "resolved", existing_correlation.status
    assert_equal "Updated description", existing_correlation.description
  end

  test "should remove correlations for issues no longer found" do
    team_member = @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    # Create existing correlations
    team_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Issue to keep",
      status: "open",
      issue_created_at: 1.day.ago,
      issue_updated_at: 1.day.ago
    )

    team_member.issue_correlations.create!(
      github_issue_number: 456,
      github_issue_url: "https://github.com/test/repo/issues/456",
      title: "Issue to remove",
      status: "open",
      issue_created_at: 1.day.ago,
      issue_updated_at: 1.day.ago
    )

    job = IssueCorrelationFinderJob.new

    # Mock API client that only returns one of the issues
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      [
        {
          github_issue_number: 123,
          github_issue_url: "https://github.com/test/repo/issues/123",
          title: "Issue to keep",
          body: "Description",
          state: "open",
          created_at: 1.day.ago,
          updated_at: 1.day.ago
        }
      ]
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)
    job.perform(@team.id)

    # Should only have one correlation left
    assert_equal 1, team_member.issue_correlations.count
    assert_equal 123, team_member.issue_correlations.first.github_issue_number
  end

  test "should remove all correlations when no issues found" do
    team_member = @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    # Create existing correlation
    team_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Issue to remove",
      status: "open",
      issue_created_at: 1.day.ago,
      issue_updated_at: 1.day.ago
    )

    job = IssueCorrelationFinderJob.new

    # Mock API client that returns no issues
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      []
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)
    job.perform(@team.id)

    # Should have no correlations left
    assert_equal 0, team_member.issue_correlations.count
  end

  test "should only process active team members" do
    # Create active and inactive members
    active_member = @team.team_members.create!(
      github_login: "active_user",
      name: "Active User",
      active: true
    )

    inactive_member = @team.team_members.create!(
      github_login: "inactive_user",
      name: "Inactive User",
      active: false
    )

    job = IssueCorrelationFinderJob.new

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.search_issues(query, repository:)
      # Return different results based on the query to track which member was processed
      if query.include?("active_user")
        [ { github_issue_number: 123, github_issue_url: "test", title: "Active issue",
          body: "desc", state: "open", created_at: 1.day.ago, updated_at: 1.day.ago } ]
      else
        [ { github_issue_number: 456, github_issue_url: "test", title: "Inactive issue",
          body: "desc", state: "open", created_at: 1.day.ago, updated_at: 1.day.ago } ]
      end
    end

    # Inject the mock API client
    job.instance_variable_set(:@api_client, mock_api_client)
    job.perform(@team.id)

    # Only active member should have correlations
    assert_equal 1, active_member.issue_correlations.count
    assert_equal 0, inactive_member.issue_correlations.count
  end

  test "should set issue correlation status to failed on error" do
    @team.team_members.destroy_all
    @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    # Mock the job to raise an error during find_correlations_for_team
    job = IssueCorrelationFinderJob.new
    job.stub :find_correlations_for_team, ->() { raise StandardError.new("Test error") } do
      assert_raises StandardError do
        job.perform(@team.id)
      end

      # Check that team issue_correlation_status was set to failed
      @team.reload
      assert_equal "failed", @team.issue_correlation_status
    end
  end

  test "sanitizes search terms to prevent injection" do
    job = IssueCorrelationFinderJob.new

    # Test malicious search terms with special characters
    malicious_terms = 'evil" OR 1=1 --'
    sanitized = job.send(:sanitize_search_term, malicious_terms)
    assert_equal "evil OR 11 --", sanitized

    # Test with quotes and brackets
    complex_terms = 'test"[injection]<script>'
    sanitized = job.send(:sanitize_search_term, complex_terms)
    assert_equal "testinjectionscript", sanitized

    # Test length truncation
    long_term = "a" * 200
    sanitized = job.send(:sanitize_search_term, long_term)
    assert_equal 100, sanitized.length

    # Test nil and empty handling
    assert_equal "", job.send(:sanitize_search_term, nil)
    assert_equal "", job.send(:sanitize_search_term, "")
  end

  test "builds safe search queries" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@search_terms, "test terms")

    # Test normal case
    query = job.send(:build_search_query, "normal_user")
    expected = 'is:issue "normal_user" in:body "normal_user" in:title "test terms"'
    assert_equal expected, query

    # Test with potentially malicious input
    job.instance_variable_set(:@search_terms, 'evil" injection')
    query = job.send(:build_search_query, "user\"evil")
    expected = 'is:issue "userevil" in:body "userevil" in:title "evil injection"'
    assert_equal expected, query
  end

  test "rolls back correlation updates on database error" do
    team_member = @team.team_members.create!(
      github_login: "test_user",
      name: "Test User",
      active: true
    )

    # Create some existing correlations
    team_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/test/issues/123",
      title: "Old Issue",
      description: "Old description",
      status: "open"
    )

    job = IssueCorrelationFinderJob.new

    # Mock issues to update
    issues = [
      {
        github_issue_number: 456,
        github_issue_url: "https://github.com/test/test/issues/456",
        title: "New Issue",
        body: "New description",
        state: "open",
        created_at: Time.current,
        updated_at: Time.current
      }
    ]

    # Mock IssueCorrelation.upsert_all to raise an error
    original_upsert = IssueCorrelation.method(:upsert_all)
    IssueCorrelation.define_singleton_method(:upsert_all) do |*args|
      raise ActiveRecord::RecordInvalid.new(IssueCorrelation.new)
    end

    begin
      # The transaction should roll back and preserve existing data
      assert_raises ActiveRecord::RecordInvalid do
        job.send(:update_correlations_for_member, team_member, issues)
      end

      # Original correlation should still exist (transaction rolled back)
      team_member.reload
      assert_equal 1, team_member.issue_correlations.count
      assert_equal 123, team_member.issue_correlations.first.github_issue_number
    ensure
      # Restore original method
      IssueCorrelation.define_singleton_method(:upsert_all, original_upsert)
    end
  end
end
