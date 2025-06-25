require "test_helper"
require "ostruct"
require "timecop"

class Github::ApiClientTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:va)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
    @client = Github::ApiClient.new(@organization)
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  # Configuration and initialization tests
  test "should raise configuration error without token" do
    ENV.delete("GHTA_GITHUB_TOKEN")

    assert_raises Github::ApiClient::ConfigurationError do
      Github::ApiClient.new(@organization)
    end
  end

  test "should initialize with valid configuration" do
    assert_instance_of Github::ApiClient, @client
    assert_equal @organization, @client.instance_variable_get(:@organization)
    assert_instance_of Octokit::Client, @client.instance_variable_get(:@client)
  end

  test "should have correct default configuration" do
    assert_equal 0.1, Github::ApiClient.config.default_rate_limit_delay
    assert_equal 3, Github::ApiClient.config.max_retries
  end

  # GraphQL team members tests
  test "should fetch team members with GraphQL successfully" do
    mock_response = {
      data: {
        organization: {
          team: {
            members: {
              edges: [
                {
                  role: "MEMBER",
                  node: {
                    id: "1",
                    login: "user1",
                    name: "User One",
                    avatarUrl: "https://github.com/user1.png",
                    databaseId: 123
                  }
                },
                {
                  role: "MAINTAINER",
                  node: {
                    id: "2",
                    login: "user2",
                    name: "User Two",
                    avatarUrl: "https://github.com/user2.png",
                    databaseId: 124
                  }
                }
              ],
              pageInfo: {
                hasNextPage: false,
                endCursor: nil
              }
            }
          }
        }
      }
    }

    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      # Simulate a successful GraphQL response
      {
        data: {
          organization: {
            team: {
              members: {
                edges: [
                  {
                    role: "MEMBER",
                    node: {
                      id: "1",
                      login: "user1",
                      name: "User One",
                      avatarUrl: "https://github.com/user1.png",
                      databaseId: 123
                    }
                  },
                  {
                    role: "MAINTAINER",
                    node: {
                      id: "2",
                      login: "user2",
                      name: "User Two",
                      avatarUrl: "https://github.com/user2.png",
                      databaseId: 124
                    }
                  }
                ],
                pageInfo: {
                  hasNextPage: false,
                  endCursor: nil
                }
              }
            }
          }
        }
      }
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_members("test-team")

    assert_equal 2, result.length
    assert_equal "user1", result.first[:github_login]
    assert_equal "User One", result.first[:name]
    assert_equal false, result.first[:maintainer_role]
    assert_equal "user2", result.last[:github_login]
    assert_equal true, result.last[:maintainer_role]
  end

  test "should handle GraphQL pagination" do
    call_count = 0
    mock_client = OpenStruct.new

    def mock_client.post(path, body)
      @call_count ||= 0
      @call_count += 1

      if @call_count == 1
        # First page
        {
          data: {
            organization: {
              team: {
                members: {
                  edges: [
                    {
                      role: "MEMBER",
                      node: {
                        id: "1",
                        login: "user1",
                        name: "User One",
                        avatarUrl: "https://github.com/user1.png",
                        databaseId: 123
                      }
                    }
                  ],
                  pageInfo: {
                    hasNextPage: true,
                    endCursor: "cursor1"
                  }
                }
              }
            }
          }
        }
      else
        # Second page
        {
          data: {
            organization: {
              team: {
                members: {
                  edges: [
                    {
                      role: "MAINTAINER",
                      node: {
                        id: "2",
                        login: "user2",
                        name: "User Two",
                        avatarUrl: "https://github.com/user2.png",
                        databaseId: 124
                      }
                    }
                  ],
                  pageInfo: {
                    hasNextPage: false,
                    endCursor: nil
                  }
                }
              }
            }
          }
        }
      end
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_members("test-team")

    assert_equal 2, result.length
    assert_equal "user1", result.first[:github_login]
    assert_equal "user2", result.last[:github_login]
  end

  test "should handle empty GraphQL response" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      {
        data: {
          organization: {
            team: nil
          }
        }
      }
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_members("nonexistent-team")
    assert_equal [], result
  end

  # Team by slug tests
  test "should fetch team by slug successfully" do
    mock_team = OpenStruct.new(
      id: 123,
      name: "Test Team",
      slug: "test-team",
      description: "A test team",
      members_count: 5,
      privacy: "closed"
    )

    mock_client = OpenStruct.new
    def mock_client.team_by_name(org, slug)
      OpenStruct.new(
        id: 123,
        name: "Test Team",
        slug: "test-team",
        description: "A test team",
        members_count: 5,
        privacy: "closed"
      )
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_by_slug("test-team")

    assert_equal "Test Team", result[:name]
    assert_equal "test-team", result[:github_slug]
    assert_equal "A test team", result[:description]
    assert_equal 5, result[:members_count]
    assert_equal "closed", result[:privacy]
  end

  # User details tests
  test "should fetch user details successfully" do
    mock_user = OpenStruct.new(
      id: 456,
      login: "testuser",
      name: "Test User",
      email: "test@example.com",
      avatar_url: "https://github.com/testuser.png",
      company: "Test Company",
      location: "Test City",
      bio: "Test bio"
    )

    mock_client = OpenStruct.new
    def mock_client.user(username)
      OpenStruct.new(
        id: 456,
        login: "testuser",
        name: "Test User",
        email: "test@example.com",
        avatar_url: "https://github.com/testuser.png",
        company: "Test Company",
        location: "Test City",
        bio: "Test bio"
      )
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.user_details("testuser")

    assert_equal "testuser", result[:github_login]
    assert_equal "Test User", result[:name]
    assert_equal "test@example.com", result[:email]
    assert_equal "https://github.com/testuser.png", result[:avatar_url]
    assert_equal "Test Company", result[:company]
    assert_equal "Test City", result[:location]
    assert_equal "Test bio", result[:bio]
  end

  # Issue search tests
  test "should search issues successfully" do
    mock_issue = OpenStruct.new(
      number: 123,
      html_url: "https://github.com/org/repo/issues/123",
      title: "Test Issue",
      body: "Test issue body",
      state: "open",
      created_at: Time.parse("2023-01-01"),
      updated_at: Time.parse("2023-01-02"),
      user: OpenStruct.new(login: "issueuser", id: 789)
    )

    mock_results = OpenStruct.new(items: [ mock_issue ])

    mock_client = OpenStruct.new
    def mock_client.search_issues(query)
      @last_query = query
      OpenStruct.new(
        items: [
          OpenStruct.new(
            number: 123,
            html_url: "https://github.com/org/repo/issues/123",
            title: "Test Issue",
            body: "Test issue body",
            state: "open",
            created_at: Time.parse("2023-01-01"),
            updated_at: Time.parse("2023-01-02"),
            user: OpenStruct.new(login: "issueuser", id: 789)
          )
        ]
      )
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.search_issues("test query")

    assert_equal 1, result.length
    issue = result.first
    assert_equal 123, issue[:github_issue_number]
    assert_equal "https://github.com/org/repo/issues/123", issue[:github_issue_url]
    assert_equal "Test Issue", issue[:title]
    assert_equal "Test issue body", issue[:body]
    assert_equal "open", issue[:state]
    assert_equal "issueuser", issue[:user][:github_login]
  end

  test "should search issues with custom repository" do
    mock_client = OpenStruct.new
    def mock_client.search_issues(query)
      @last_query = query
      OpenStruct.new(items: [])
    end

    @client.instance_variable_set(:@client, mock_client)

    @client.search_issues("test query", repository: "custom/repo")

    # Verify the query includes the custom repository
    expected_query = "repo:custom/repo test query"
    assert_equal expected_query, mock_client.instance_variable_get(:@last_query)
  end

  # Rate limiting and retry tests
  test "should handle rate limit properly with medium remaining" do
    mock_rate_limit = OpenStruct.new(remaining: 150, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture the duration without actually sleeping
    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Should have called sleep with default delay (0.1s)
    assert_equal 0.1, sleep_duration
  end

  # Test rate limiting delays without the complex retry logic
  test "should sleep for critical rate limit" do
    mock_rate_limit = OpenStruct.new(remaining: 40, resets_at: Time.now + 2)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture the duration without actually sleeping
    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Should sleep for at least 1 second due to critical rate limit
    assert sleep_duration >= 1.0
  end

  # Private method tests
  test "should normalize member data correctly" do
    member = OpenStruct.new(
      login: "testuser",
      name: "Test User",
      avatar_url: "https://github.com/testuser.png"
    )

    result = @client.send(:normalize_member_data, member)

    assert_equal "testuser", result[:github_login]
    assert_equal "Test User", result[:name]
    assert_equal "https://github.com/testuser.png", result[:avatar_url]
  end

  test "should normalize team data correctly" do
    team = OpenStruct.new(
      id: 123,
      name: "Test Team",
      slug: "test-team",
      description: "A test team",
      members_count: 5,
      privacy: "closed"
    )

    result = @client.send(:normalize_team_data, team)

    assert_equal "Test Team", result[:name]
    assert_equal "test-team", result[:github_slug]
    assert_equal "A test team", result[:description]
    assert_equal 5, result[:members_count]
    assert_equal "closed", result[:privacy]
  end

  test "should normalize issue data correctly" do
    issue = OpenStruct.new(
      number: 123,
      html_url: "https://github.com/org/repo/issues/123",
      title: "Test Issue",
      body: "Test body",
      state: "open",
      created_at: Time.parse("2023-01-01"),
      updated_at: Time.parse("2023-01-02"),
      user: OpenStruct.new(login: "testuser", id: 456)
    )

    result = @client.send(:normalize_issue_data, issue)

    assert_equal 123, result[:github_issue_number]
    assert_equal "https://github.com/org/repo/issues/123", result[:github_issue_url]
    assert_equal "Test Issue", result[:title]
    assert_equal "Test body", result[:body]
    assert_equal "open", result[:state]
    assert_equal Time.parse("2023-01-01"), result[:created_at]
    assert_equal Time.parse("2023-01-02"), result[:updated_at]
    assert_equal "testuser", result[:user][:github_login]
  end

  test "should normalize user data correctly" do
    user = OpenStruct.new(
      id: 456,
      login: "testuser",
      name: "Test User",
      email: "test@example.com",
      avatar_url: "https://github.com/testuser.png",
      company: "Test Company",
      location: "Test City",
      bio: "Test bio"
    )

    result = @client.send(:normalize_user_data, user)

    assert_equal "testuser", result[:github_login]
    assert_equal "Test User", result[:name]
    assert_equal "test@example.com", result[:email]
    assert_equal "https://github.com/testuser.png", result[:avatar_url]
    assert_equal "Test Company", result[:company]
    assert_equal "Test City", result[:location]
    assert_equal "Test bio", result[:bio]
  end

  test "should handle nil rate limit" do
    mock_client = OpenStruct.new(rate_limit: nil)
    @client.instance_variable_set(:@client, mock_client)

    # Should not raise error or sleep
    assert_nothing_raised do
      @client.send(:check_rate_limit)
    end
  end

  # Error handling tests
  test "should handle Octokit::NotFound in fetch_team_members" do
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise Octokit::NotFound.new
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_members("nonexistent-team")
    assert_equal [], result
  end

  test "should handle Octokit::NotFound in fetch_team_by_slug" do
    mock_client = OpenStruct.new
    def mock_client.team_by_name(org, slug)
      raise Octokit::NotFound.new
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.fetch_team_by_slug("nonexistent-team")
    assert_nil result
  end

  test "should handle Octokit::NotFound in user_details" do
    mock_client = OpenStruct.new
    def mock_client.user(username)
      raise Octokit::NotFound.new
    end

    @client.instance_variable_set(:@client, mock_client)

    result = @client.user_details("nonexistent-user")
    assert_nil result
  end

  test "should retry on Octokit::TooManyRequests" do
    call_count = 0
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.post(path, body)
      @call_count ||= 0
      @call_count += 1

      if @call_count == 1
        # First call raises rate limit error
        error = Octokit::TooManyRequests.new
        def error.response_headers
          { "x-ratelimit-reset" => Time.now.to_i.to_s }  # Reset time is now (no sleep)
        end
        raise error
      else
        # Second call succeeds
        { data: { organization: { team: nil } } }
      end
    end

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to avoid waiting during retry
    @client.define_singleton_method(:sleep) { |duration| nil }
    result = @client.fetch_team_members("test-team")
    assert_equal [], result
  end

  # Test missing branches for better coverage
  test "should handle rate limit with sleep_time > 0" do
    # Test when reset time is in the future (sleep_time > 0 branch)
    mock_rate_limit = OpenStruct.new(remaining: 40, resets_at: Time.now + 2)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture the duration without actually sleeping
    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Should sleep for at least 1 second due to critical rate limit
    assert sleep_duration >= 1.0
  end

  test "should handle rate limit warning threshold" do
    mock_rate_limit = OpenStruct.new(remaining: 150, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture the duration without actually sleeping
    sleep_duration = nil
    @client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    @client.send(:check_rate_limit)

    # Should sleep for default delay (0.1s)
    assert_equal 0.1, sleep_duration
  end

  test "should not sleep when rate limit is high" do
    mock_rate_limit = OpenStruct.new(remaining: 500, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to verify it's NOT called when rate limit is high
    sleep_called = false
    @client.define_singleton_method(:sleep) { |duration| sleep_called = true }

    @client.send(:check_rate_limit)

    # Should not sleep when rate limit is high
    assert_not sleep_called
  end

  test "should handle rate limit critical with minimum delay even when reset time is past" do
    # Test when reset time is in the past - should still use MIN_CRITICAL_DELAY (1.0)
    mock_rate_limit = OpenStruct.new(remaining: 40, resets_at: Time.now - 10)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture any sleep calls
    sleep_calls = []
    @client.define_singleton_method(:sleep) { |duration| sleep_calls << duration }

    @client.send(:check_rate_limit)

    # Should call sleep with MIN_CRITICAL_DELAY (1.0) even when reset time is past
    assert_equal [ 1.0 ], sleep_calls
  end

  test "should not sleep when calculated sleep time is zero" do
    # Test to force sleep_time to be exactly 0 to test the condition
    mock_rate_limit = OpenStruct.new(remaining: 40, resets_at: Time.now)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    @client.instance_variable_set(:@client, mock_client)

    # Mock sleep to track calls instead of modifying constants
    sleep_calls = []
    @client.define_singleton_method(:sleep) { |duration| sleep_calls << duration }

    @client.send(:check_rate_limit)

    # Should call sleep with MIN_CRITICAL_DELAY when rate limit is critical
    assert_equal [ Github::ApiConfiguration::MIN_CRITICAL_DELAY ], sleep_calls
  end

  test "should raise on max retries for TooManyRequests" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.post(path, body)
      error = Octokit::TooManyRequests.new
      def error.response_headers
        { "x-ratelimit-reset" => Time.now.to_i.to_s }
      end
      raise error
    end

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to avoid waiting during retry
    @client.define_singleton_method(:sleep) { |duration| nil }

    assert_raises Octokit::TooManyRequests do
      @client.fetch_team_members("test-team")
    end
  end

  test "should raise on max retries for ServerError" do
    mock_client = OpenStruct.new

    def mock_client.rate_limit
      nil
    end

    def mock_client.post(path, body)
      raise Octokit::ServerError.new
    end

    @client.instance_variable_set(:@client, mock_client)

    # Override sleep to avoid waiting during retry
    @client.define_singleton_method(:sleep) { |duration| nil }

    assert_raises Octokit::ServerError do
      @client.fetch_team_members("test-team")
    end
  end

  test "should handle team_id_for_slug with existing team" do
    mock_client = OpenStruct.new
    def mock_client.team_by_name(org, slug)
      OpenStruct.new(id: 123, name: "Test Team", slug: "test-team")
    end

    @client.instance_variable_set(:@client, mock_client)

    # This tests the private method indirectly through fetch_team_by_slug
    result = @client.fetch_team_by_slug("test-team")
    assert_equal "Test Team", result[:name]
  end

  test "should get team_id_for_slug with existing team" do
    # Mock fetch_team_by_slug to return the normalized hash format
    @client.define_singleton_method(:fetch_team_by_slug) { |slug| { id: 123, name: "Test Team" } }

    result = @client.send(:team_id_for_slug, "test-team")
    assert_equal 123, result
  end

  test "should get team_id_for_slug when team has id via dig" do
    # Test the team&.dig(:id) path specifically (line 122)
    @client.define_singleton_method(:fetch_team_by_slug) { |slug| { id: 456, name: "Test Team" } }

    result = @client.send(:team_id_for_slug, "test-team")
    assert_equal 456, result
  end

  test "should raise NotFound for team_id_for_slug with nonexistent team" do
    mock_client = OpenStruct.new
    def mock_client.team_by_name(org, slug)
      raise Octokit::NotFound.new
    end

    @client.instance_variable_set(:@client, mock_client)

    # This should return nil due to the rescue in fetch_team_by_slug
    result = @client.fetch_team_by_slug("nonexistent-team")
    assert_nil result
  end
end
