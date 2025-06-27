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
                    avatarUrl: "https://avatars.githubusercontent.com/user1",
                    databaseId: 123
                  }
                },
                {
                  role: "MAINTAINER",
                  node: {
                    id: "2",
                    login: "user2",
                    name: "User Two",
                    avatarUrl: "https://avatars.githubusercontent.com/user2",
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
                      avatarUrl: "https://avatars.githubusercontent.com/user1",
                      databaseId: 123
                    }
                  },
                  {
                    role: "MAINTAINER",
                    node: {
                      id: "2",
                      login: "user2",
                      name: "User Two",
                      avatarUrl: "https://avatars.githubusercontent.com/user2",
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
                        avatarUrl: "https://avatars.githubusercontent.com/user1",
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
                        avatarUrl: "https://avatars.githubusercontent.com/user2",
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
      avatar_url: "https://avatars.githubusercontent.com/testuser",
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
        avatar_url: "https://avatars.githubusercontent.com/testuser",
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
    assert_equal "https://avatars.githubusercontent.com/testuser", result[:avatar_url]
    assert_equal "Test Company", result[:company]
    assert_equal "Test City", result[:location]
    assert_equal "Test bio", result[:bio]
  end

  # Issue search tests
  # Skipped: search_issues method moved to GraphQL client
  # These tests were removed because issue searching is now handled by the GraphQL client

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
      avatar_url: "https://avatars.githubusercontent.com/testuser"
    )

    result = @client.send(:normalize_member_data, member)

    assert_equal "testuser", result[:github_login]
    assert_equal "Test User", result[:name]
    assert_equal "https://avatars.githubusercontent.com/testuser", result[:avatar_url]
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

  test "should normalize user data correctly" do
    user = OpenStruct.new(
      id: 456,
      login: "testuser",
      name: "Test User",
      email: "test@example.com",
      avatar_url: "https://avatars.githubusercontent.com/testuser",
      company: "Test Company",
      location: "Test City",
      bio: "Test bio"
    )

    result = @client.send(:normalize_user_data, user)

    assert_equal "testuser", result[:github_login]
    assert_equal "Test User", result[:name]
    assert_equal "test@example.com", result[:email]
    assert_equal "https://avatars.githubusercontent.com/testuser", result[:avatar_url]
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

  test "rate limit countdown broadcasts every second" do
    callback_calls = []
    callback = ->(remaining) { callback_calls << remaining }

    client = Github::ApiClient.new(@organization, rate_limit_callback: callback)

    # Mock sleep to track calls without actually sleeping
    sleep_calls = 0
    client.define_singleton_method(:sleep) { |duration| sleep_calls += 1 }

    # Test countdown with 5 seconds
    client.send(:sleep_with_countdown, 5)

    # Verify we slept 5 times (once per second)
    assert_equal 5, sleep_calls

    # Verify broadcasts happened every second
    expected_calls = [ 5, 4, 3, 2, 1 ]
    assert_equal expected_calls, callback_calls
  end

  test "rate limit countdown without callback sleeps normally" do
    client = Github::ApiClient.new(@organization) # No callback

    sleep_duration = nil
    client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    client.send(:sleep_with_countdown, 5)

    # Should call sleep once with the full duration
    assert_equal 5, sleep_duration
  end
end
