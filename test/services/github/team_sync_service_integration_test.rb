require "test_helper"

class Github::TeamSyncServiceIntegrationTest < ActiveSupport::TestCase
  setup do
    @team = teams(:platform_security)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "should sync team members with mock data" do
    service = Github::TeamSyncService.new(@team)

    # Mock the API client methods
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "testuser1",
          name: "Test User 1",
          avatar_url: "https://github.com/testuser1.png",
          maintainer_role: false
        },
        {
          github_login: "testuser2",
          name: "Test User 2",
          avatar_url: "https://github.com/testuser2.png",
          maintainer_role: true
        }
      ]
    end

    def mock_api_client.user_details(username)
      {
        name: "Enhanced #{username}",
        email: "#{username}@va.gov",
        company: "Department of Veterans Affairs"
      }
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    # Clear existing members
    @team.team_members.destroy_all

    result = service.sync_team_members

    assert_equal 2, result[:total]
    assert_equal 2, result[:new_members]
    assert_equal 0, result[:updated]

    # Check members were created
    assert_equal 2, @team.team_members.count

    member1 = @team.team_members.find_by(github_login: "testuser1")
    assert_equal "Test User 1", member1.name # Uses basic name from GraphQL, not enhanced
    assert_not member1.government_employee # Default false, enriched later in background
    assert_not member1.maintainer_role

    member2 = @team.team_members.find_by(github_login: "testuser2")
    assert member2.maintainer_role
  end

  test "should handle fetch errors gracefully" do
    service = Github::TeamSyncService.new(@team)

    # Mock API client that throws errors
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      raise StandardError.new("API Error")
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    assert_raises StandardError do
      service.sync_team_members
    end
  end

  test "should update existing members" do
    service = Github::TeamSyncService.new(@team)

    # Create existing member
    existing_member = @team.team_members.create!(
      github_login: "testuser1",
      name: "Old Name",
      maintainer_role: false
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "testuser1",
          name: "New Name",
          avatar_url: "https://github.com/testuser1.png",
          maintainer_role: true
        }
      ]
    end

    def mock_api_client.user_details(username)
      {
        name: "New Name",
        email: "#{username}@contractor.com",
        company: "Contractor LLC"
      }
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    result = service.sync_team_members

    assert_equal 1, result[:total]
    assert_equal 0, result[:new_members]
    assert_equal 1, result[:updated]

    existing_member.reload
    assert_equal "New Name", existing_member.name
    assert existing_member.maintainer_role
    assert_not existing_member.government_employee
  end

  test "should mark absent members" do
    service = Github::TeamSyncService.new(@team)

    # Create existing members
    present_member = @team.team_members.create!(
      github_login: "present",
      last_seen_at: Time.current
    )

    absent_member = @team.team_members.create!(
      github_login: "absent",
      last_seen_at: Time.current
    )

    # Mock API that only returns present member
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "present",
          name: "Present User",
          avatar_url: "https://github.com/present.png",
          maintainer_role: false
        }
      ]
    end

    def mock_api_client.user_details(username)
      nil
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    service.sync_team_members

    present_member.reload
    absent_member.reload

    # Present member should have recent last_seen_at and be active
    assert present_member.last_seen_at > 1.minute.ago
    assert present_member.active?

    # Absent member should be marked as inactive
    assert_not absent_member.active?
  end

  test "should prevent data loss when API returns empty" do
    service = Github::TeamSyncService.new(@team)

    # Clear any existing members first
    @team.team_members.destroy_all

    # Create existing member
    @team.team_members.create!(
      github_login: "existing_user",
      name: "Existing User"
    )

    # Mock API client that returns empty
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      []
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    assert_raises RuntimeError, "API returned empty member list - possible API issue or incorrect team configuration" do
      service.sync_team_members
    end

    # Ensure existing member wasn't deleted
    assert_equal 1, @team.team_members.count
  end

  test "should prevent duplicates when syncing same member multiple times" do
    service = Github::TeamSyncService.new(@team)

    # Clear any existing members first
    @team.team_members.destroy_all

    # Mock API client that returns same member
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "testuser1",
          name: "Test User 1",
          avatar_url: "https://github.com/testuser1.png",
          maintainer_role: false
        }
      ]
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    # Sync twice - should not create duplicates
    result1 = service.sync_team_members
    assert_equal 1, result1[:new_members], "First sync should create 1 new member"
    assert_equal 1, @team.team_members.count, "Should have 1 member after first sync"

    result2 = service.sync_team_members
    assert_equal 0, result2[:new_members], "Second sync should create 0 new members"
    assert_equal 1, result2[:updated], "Second sync should update 1 existing member"

    # Should only have one member despite syncing twice
    @team.reload
    assert_equal 1, @team.team_members.count

    member = @team.team_members.first
    assert_not_nil member, "Member should exist"
    assert_equal "testuser1", member.github_login
  end
end
