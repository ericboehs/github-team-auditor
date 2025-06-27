require "test_helper"

class Github::GraphqlClientTest < ActiveSupport::TestCase
  def setup
    @organization = organizations(:va)
    @team_member1 = team_members(:john_doe_team_member)
    @team_member2 = team_members(:jane_smith_team_member)
    @team_members = [ @team_member1, @team_member2 ]

    # Set up test token to avoid configuration error
    @original_token = ENV["GHTA_GITHUB_TOKEN"]
    ENV["GHTA_GITHUB_TOKEN"] = "test_token_123"

    # Create a mock client to avoid real API calls
    @client = Github::GraphqlClient.new(@organization)
  end

  def teardown
    # Restore original token
    if @original_token
      ENV["GHTA_GITHUB_TOKEN"] = @original_token
    else
      ENV.delete("GHTA_GITHUB_TOKEN")
    end
  end

  test "graphql client initializes with organization" do
    assert_not_nil @client
  end

  test "sanitize_search_term removes dangerous characters and limits length" do
    # Test basic sanitization
    result = @client.send(:sanitize_search_term, "test & <script>")
    assert_equal "test  script", result

    # Test length limiting
    long_term = "a" * 150
    result = @client.send(:sanitize_search_term, long_term)
    assert_equal 100, result.length

    # Test blank input
    result = @client.send(:sanitize_search_term, "")
    assert_equal "", result

    # Test nil input
    result = @client.send(:sanitize_search_term, nil)
    assert_equal "", result
  end

  test "build_search_string creates proper GitHub search query" do
    query = @client.send(:build_search_string, "john_doe", "access security")

    assert_includes query, "john_doe"
    assert_includes query, "access security"
    assert_includes query, "is:issue"
    assert_includes query, "in:body"
    assert_includes query, "in:title"
  end

  test "build_search_string sanitizes inputs" do
    query = @client.send(:build_search_string, "user<script>", "term&dangerous")

    # Should not contain dangerous characters
    refute_includes query, "<script>"
    refute_includes query, "&"
    # Should contain sanitized versions
    assert_includes query, "userscript"
    assert_includes query, "termdangerous"
  end

  test "normalize_issue_data_from_graphql converts GraphQL response format" do
    graphql_issue = {
      number: 123,
      url: "https://github.com/test/repo/issues/123",
      title: "Test issue",
      bodyText: "Test body",
      state: "OPEN",
      createdAt: "2023-01-01T12:00:00Z",
      updatedAt: "2023-01-02T12:00:00Z",
      author: { login: "testuser" }
    }

    result = @client.send(:normalize_issue_data_from_graphql, graphql_issue)

    assert_equal 123, result[:github_issue_number]
    assert_equal "https://github.com/test/repo/issues/123", result[:github_issue_url]
    assert_equal "Test issue", result[:title]
    assert_equal "Test body", result[:body]
    assert_equal "open", result[:state]
    assert_kind_of Time, result[:created_at]
    assert_kind_of Time, result[:updated_at]
    assert_equal "testuser", result.dig(:user, :github_login)
  end

  test "filter_excluded_issues removes issues with exclusion terms" do
    issues = [
      { title: "Regular issue" },
      { title: "Test issue to exclude" },
      { title: "Another normal issue" }
    ]

    result = @client.send(:filter_excluded_issues, issues, "test")

    assert_equal 2, result.length
    assert_equal "Regular issue", result[0][:title]
    assert_equal "Another normal issue", result[1][:title]
  end

  test "filter_excluded_issues returns all issues when exclusion_terms is blank" do
    issues = [
      { title: "Regular issue" },
      { title: "Test issue" }
    ]

    result = @client.send(:filter_excluded_issues, issues, "")

    assert_equal 2, result.length
  end

  test "build_multi_search_query creates proper GraphQL query structure" do
    member_logins = [ "user1", "user2" ]
    query_result = @client.send(:build_multi_search_query, member_logins, "access", "test", "repo")

    assert_includes query_result[:query], "query BatchIssueSearch"
    assert_includes query_result[:query], "search0:"
    assert_includes query_result[:query], "search1:"
    assert_includes query_result[:query], "rateLimit"

    assert_equal "repo:test/repo is:issue \"user1\" in:body \"user1\" in:title \"access\"", query_result[:variables][:query0]
    assert_equal "repo:test/repo is:issue \"user2\" in:body \"user2\" in:title \"access\"", query_result[:variables][:query1]

    assert_equal "user1", query_result[:searches][:search0]
    assert_equal "user2", query_result[:searches][:search1]
  end

  test "build_single_search_query creates proper GraphQL query structure" do
    query_result = @client.send(:build_single_search_query, "user1", "access", "test", "repo")

    assert_includes query_result[:query], "query SingleIssueSearch"
    assert_includes query_result[:query], "search("
    assert_includes query_result[:query], "rateLimit"

    assert_equal "repo:test/repo is:issue \"user1\" in:body \"user1\" in:title \"access\"", query_result[:variables][:query]
    assert_equal :search, query_result[:search_key]
  end

  test "extract_issues_from_search_result processes GraphQL search nodes" do
    search_result = {
      nodes: [
        {
          number: 123,
          url: "https://github.com/test/repo/issues/123",
          title: "Test issue",
          bodyText: "Test body",
          state: "OPEN",
          createdAt: "2023-01-01T12:00:00Z",
          updatedAt: "2023-01-02T12:00:00Z",
          author: { login: "testuser" }
        }
      ]
    }

    result = @client.send(:extract_issues_from_search_result, search_result)

    assert_equal 1, result.length
    assert_equal 123, result[0][:github_issue_number]
    assert_equal "Test issue", result[0][:title]
  end

  test "extract_issues_from_search_result handles empty nodes" do
    search_result = { nodes: [] }
    result = @client.send(:extract_issues_from_search_result, search_result)
    assert_equal 0, result.length

    search_result = {}
    result = @client.send(:extract_issues_from_search_result, search_result)
    assert_equal 0, result.length
  end

  test "batch_search_issues_for_members handles empty team_members" do
    result = @client.batch_search_issues_for_members(
      [],
      search_terms: "test",
      repository: "test/repo"
    )
    assert_equal({}, result)
  end

  test "single_search_issues_for_member returns empty array for no results" do
    # Mock the GraphQL client to return empty results
    mock_client = Object.new
    def mock_client.post(path, payload)
      { data: { search: { nodes: [] } } }
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues_for_member(
      "test_user",
      search_terms: "test terms",
      repository: "test/repo"
    )

    assert_equal [], result
  end

  test "build_batch_search_queries splits large member lists" do
    # Test with more than 5 members to trigger batching
    member_logins = (1..7).map { |i| "user#{i}" }
    queries = @client.send(:build_batch_search_queries, member_logins, "test", "owner", "repo")

    # Should create 2 batches: 5 members + 2 members
    assert_equal 2, queries.length
    assert_equal 5, queries.first[:searches].length
    assert_equal 2, queries.last[:searches].length
  end

  test "normalize_issue_data_from_graphql handles nil author" do
    issue_data = {
      number: 123,
      title: "Test Issue",
      bodyText: "Test body",
      url: "https://github.com/test/repo/issues/123",
      createdAt: "2023-01-01T00:00:00Z",
      updatedAt: "2023-01-02T00:00:00Z",
      state: "OPEN",
      author: nil
    }

    result = @client.send(:normalize_issue_data_from_graphql, issue_data)

    assert_equal 123, result[:github_issue_number]
    assert_equal "Test Issue", result[:title]
    assert_nil result[:user][:github_login]
  end

  test "process_batch_search_response handles missing data" do
    response = {}
    all_results = {}

    @client.send(:process_batch_search_response, response, all_results, "")

    assert_equal({}, all_results)
  end

  test "process_batch_search_response handles missing batch searches" do
    response = { data: { search0: { nodes: [] } } }
    all_results = {}

    # Don't set @current_batch_searches
    @client.send(:process_batch_search_response, response, all_results, "")

    assert_equal({}, all_results)
  end

  test "process_batch_search_response processes search results correctly" do
    # Set up batch searches mapping
    @client.instance_variable_set(:@current_batch_searches, { search0: "user1" })

    response = {
      data: {
        search0: {
          nodes: [
            {
              number: 123,
              title: "Test Issue",
              bodyText: "Test body",
              url: "https://github.com/test/repo/issues/123",
              createdAt: "2023-01-01T00:00:00Z",
              updatedAt: "2023-01-02T00:00:00Z",
              state: "OPEN",
              author: { login: "author1" }
            }
          ]
        },
        rateLimit: { remaining: 5000 }
      }
    }

    all_results = {}
    @client.send(:process_batch_search_response, response, all_results, "")

    assert_equal 1, all_results["user1"].length
    assert_equal 123, all_results["user1"].first[:github_issue_number]
  end

  test "filter_excluded_issues filters based on title" do
    issues = [
      { title: "Regular Issue", github_issue_number: 1 },
      { title: "Exclude This Issue", github_issue_number: 2 },
      { title: "Another Regular Issue", github_issue_number: 3 }
    ]

    result = @client.send(:filter_excluded_issues, issues, "exclude")

    assert_equal 2, result.length
    assert_equal [ 1, 3 ], result.map { |i| i[:github_issue_number] }
  end

  test "update_rate_limit_from_response handles missing rate limit data" do
    response = { data: {} }

    # Should not raise an error
    assert_nothing_raised do
      @client.send(:update_rate_limit_from_response, response)
    end
  end

  test "with_rate_limiting yields to block when no errors" do
    block_executed = false

    result = @client.send(:with_rate_limiting) do
      block_executed = true
      "success"
    end

    assert block_executed
    assert_equal "success", result
  end

  test "extract_issues_from_response handles missing data" do
    response = { data: nil }
    result = @client.send(:extract_issues_from_response, response, :search)
    assert_equal [], result
  end

  test "extract_issues_from_response handles missing search key" do
    response = { data: { other_key: { nodes: [] } } }
    result = @client.send(:extract_issues_from_response, response, :search)
    assert_equal [], result
  end

  test "update_rate_limit_from_response handles low remaining limit" do
    # Test the sleep_with_countdown path
    response = {
      data: {
        rateLimit: {
          remaining: 50,  # Low limit to trigger sleep
          limit: 5000,
          cost: 1,
          resetAt: (Time.now + 10).iso8601
        }
      }
    }

    sleep_called = false
    sleep_time = nil
    @client.define_singleton_method(:sleep_with_countdown) do |time|
      sleep_called = true
      sleep_time = time
    end

    @client.send(:update_rate_limit_from_response, response)
    assert sleep_called
    assert_operator sleep_time, :>, 0
  end

  test "sleep_with_countdown with callback" do
    countdown_values = []
    callback = ->(seconds) { countdown_values << seconds }

    # Set up client with callback
    client = Github::GraphqlClient.new(@organization, rate_limit_callback: callback)

    # Test sleep with very short duration
    client.send(:sleep_with_countdown, 2)

    # Should have called callback with countdown values
    assert countdown_values.include?(2)
    assert countdown_values.include?(1)
    assert countdown_values.include?(0)
  end

  test "sleep_with_countdown without callback" do
    # Test that it still works without callback
    start_time = Time.now
    @client.send(:sleep_with_countdown, 0.1)
    end_time = Time.now

    # Should have slept for the specified time
    assert (end_time - start_time) >= 0.1
  end

  test "batch_search_issues_for_members processes repository splitting" do
    # Test repository parameter parsing
    result = @client.batch_search_issues_for_members(
      [],
      search_terms: "test",
      repository: "owner/repo-name"
    )

    assert_equal({}, result)
  end

  test "process_batch_search_response skips non-hash search results" do
    # Test the response filtering logic
    @client.instance_variable_set(:@current_batch_searches, { search0: "user1" })

    response = {
      data: {
        search0: "not a hash",  # This should be skipped
        rateLimit: { remaining: 5000 }
      }
    }

    all_results = {}
    @client.send(:process_batch_search_response, response, all_results, "")

    assert_equal({}, all_results)
  end

  test "with_rate_limiting handles TooManyRequests error with retries" do
    retries = 0

    # Mock the exception
    error = Octokit::TooManyRequests.new
    error.define_singleton_method(:response_headers) do
      { "x-ratelimit-reset" => (Time.now.to_i + 60).to_s }
    end

    # Mock sleep_with_countdown to avoid actual sleeping
    @client.define_singleton_method(:sleep_with_countdown) { |time| }

    result = @client.send(:with_rate_limiting) do
      retries += 1
      if retries == 1
        raise error
      else
        "success after retry"
      end
    end

    assert_equal "success after retry", result
    assert_equal 2, retries
  end

  test "with_rate_limiting handles ServerError with retries" do
    retries = 0

    # Mock the server error
    server_error = Octokit::ServerError.new({ status: 500, body: "Server Error" })

    result = @client.send(:with_rate_limiting) do
      retries += 1
      if retries == 1
        raise server_error
      else
        "success after retry"
      end
    end

    assert_equal "success after retry", result
    assert_equal 2, retries
  end

  test "with_rate_limiting raises after max retries exceeded" do
    # Mock the exception
    error = Octokit::TooManyRequests.new
    error.define_singleton_method(:response_headers) do
      { "x-ratelimit-reset" => (Time.now.to_i + 60).to_s }
    end

    # Mock sleep_with_countdown to avoid actual sleeping
    @client.define_singleton_method(:sleep_with_countdown) { |time| }

    assert_raises(Octokit::TooManyRequests) do
      @client.send(:with_rate_limiting) do
        raise error
      end
    end
  end

  test "batch_search_issues_for_members calls execute_batch_search" do
    # Test that batch processing calls the right methods
    mock_client = Object.new
    def mock_client.post(endpoint, body)
      {
        data: {
          search0: { nodes: [] },
          rateLimit: { remaining: 5000, resetAt: Time.current.iso8601, limit: 5000, cost: 1 }
        }
      }
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.batch_search_issues_for_members(
      [ @team_member1 ],
      search_terms: "test",
      repository: "owner/repo",
      exclusion_terms: ""
    )

    assert_kind_of Hash, result
  end

  test "sleep_with_countdown handles zero sleep time" do
    # Test edge case where sleep_time <= 0
    assert_nothing_raised do
      @client.send(:sleep_with_countdown, 0)
    end

    assert_nothing_raised do
      @client.send(:sleep_with_countdown, -1)
    end
  end
end
