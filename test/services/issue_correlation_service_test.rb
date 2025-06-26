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

  test "map_issue_status converts GitHub states correctly" do
    assert_equal "open", @service.send(:map_issue_status, "open")
    assert_equal "resolved", @service.send(:map_issue_status, "closed")
    assert_equal "open", @service.send(:map_issue_status, "unknown")
  end

  test "truncate_description limits description length" do
    long_body = "a" * 1500
    result = @service.send(:truncate_description, long_body)
    assert_equal 1000, result.length

    # Test nil input
    result = @service.send(:truncate_description, nil)
    assert_nil result
  end

  test "build_search_query includes login and search terms" do
    query = @service.send(:build_search_query, "john_doe")

    assert_includes query, "john_doe"
    assert_includes query, "access"
    assert_includes query, "is:issue"
  end
end
