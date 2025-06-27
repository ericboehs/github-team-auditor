require "test_helper"
require "ostruct"

class Github::ApiClientIntegrationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:va)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "should handle rate limiting" do
    client = Github::ApiClient.new(@organization)

    # Mock rate limit response (50 remaining triggers warning but not critical)
    mock_rate_limit = OpenStruct.new(remaining: 50, resets_at: Time.now + 300)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    client.instance_variable_set(:@client, mock_client)

    # Override sleep to capture duration
    sleep_duration = nil
    client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    assert_nothing_raised do
      client.send(:check_rate_limit)
    end

    # Should sleep for warning delay (50 < 200 warning threshold, but 50 >= 50 critical threshold)
    assert_equal 0.1, sleep_duration
  end

  test "should handle low rate limiting" do
    client = Github::ApiClient.new(@organization)

    # Mock low rate limit
    mock_rate_limit = OpenStruct.new(remaining: 49, resets_at: Time.now + 2)
    mock_client = OpenStruct.new(rate_limit: mock_rate_limit)

    client.instance_variable_set(:@client, mock_client)

    # Override sleep to verify rate limiting logic without actual delay
    sleep_duration = nil
    client.define_singleton_method(:sleep) { |duration| sleep_duration = duration }

    client.send(:check_rate_limit)

    # Should have called sleep for at least the rate limit delay
    assert sleep_duration >= 1.5
  end

  test "should fetch team members with error handling" do
    client = Github::ApiClient.new(@organization)

    # Mock client that raises not found for GraphQL
    mock_client = OpenStruct.new
    def mock_client.post(path, body)
      raise Octokit::NotFound.new
    end

    client.instance_variable_set(:@client, mock_client)

    result = client.fetch_team_members("test-team")
    assert_equal [], result
  end

  test "should fetch team by slug with error handling" do
    client = Github::ApiClient.new(@organization)

    # Mock client that raises not found
    mock_client = OpenStruct.new
    def mock_client.team_by_name(org, slug)
      raise Octokit::NotFound.new
    end

    client.instance_variable_set(:@client, mock_client)

    result = client.fetch_team_by_slug("test-team")
    assert_nil result
  end

  test "should get user details with error handling" do
    client = Github::ApiClient.new(@organization)

    # Mock client that raises not found
    mock_client = OpenStruct.new
    def mock_client.user(username)
      raise Octokit::NotFound.new
    end

    client.instance_variable_set(:@client, mock_client)

    result = client.user_details("testuser")
    assert_nil result
  end

  # Skipped: search_issues method moved to GraphQL client
  # This test was removed because issue searching is now handled by the GraphQL client

  test "should configure client correctly" do
    client = Github::ApiClient.new(@organization)

    mock_client = OpenStruct.new
    client.instance_variable_set(:@client, mock_client)

    client.send(:configure_client)

    assert_equal true, mock_client.auto_paginate
    assert_equal 100, mock_client.per_page
  end
end
