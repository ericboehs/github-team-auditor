require "test_helper"
require "minitest/mock"

class MemberEnrichmentJobTest < ActiveJob::TestCase
  setup do
    @team = teams(:platform_security)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "should enrich new members with user details" do
    # Create members without enriched data
    member1 = @team.team_members.create!(
      github_login: "testuser1",
      name: "Basic Name"
    )

    member2 = @team.team_members.create!(
      github_login: "testuser2",
      name: nil
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      case username
      when "testuser1"
        {
          name: "Enhanced User 1"
        }
      when "testuser2"
        {
          name: "Enhanced User 2"
        }
      end
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id, [ "testuser1", "testuser2" ])
    end

    member1.reload
    member2.reload

    assert_equal "Enhanced User 1", member1.name
    assert_equal "Enhanced User 2", member2.name
  end

  test "should handle API errors gracefully" do
    member = @team.team_members.create!(
      github_login: "testuser",
      name: "Original Name"
    )

    # Mock API client that raises errors
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      raise StandardError, "API Error"
    end

    Github::ApiClient.stub :new, mock_api_client do
      # Should not raise error, just continue
      assert_nothing_raised do
        MemberEnrichmentJob.perform_now(@team.id, [ "testuser" ])
      end
    end

    member.reload
    # Original data should be unchanged
    assert_equal "Original Name", member.name
  end

  test "should enrich all members when no specific logins provided" do
    # Create members with missing data
    member1 = @team.team_members.create!(
      github_login: "testuser1",
      name: nil
    )

    member2 = @team.team_members.create!(
      github_login: "testuser2",
      name: nil
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      {
        name: "API Name for #{username}"
      }
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id) # No specific logins
    end

    member1.reload
    member2.reload

    assert_equal "API Name for testuser1", member1.name
    assert_equal "API Name for testuser2", member2.name
  end

  test "should return early when no members to enrich" do
    # Create a member with all data already present
    @team.team_members.create!(
      github_login: "testuser",
      name: "Complete Name"
    )

    # Mock API client that should not be called
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      raise "Should not be called"
    end

    Github::ApiClient.stub :new, mock_api_client do
      assert_nothing_raised do
        MemberEnrichmentJob.perform_now(@team.id)
      end
    end
  end

  test "should handle nil user details from API" do
    member = @team.team_members.create!(
      github_login: "testuser",
      name: "Original Name"
    )

    # Mock API client that returns nil
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      nil
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id, [ "testuser" ])
    end

    member.reload
    # Original data should be unchanged
    assert_equal "Original Name", member.name
  end

  test "should be queued in default queue" do
    assert_equal "default", MemberEnrichmentJob.queue_name
  end
end
