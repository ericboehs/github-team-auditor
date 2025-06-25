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
      github_login: "present"
    )

    absent_member = @team.team_members.create!(
      github_login: "absent"
    )

    # Create issue correlations to ensure last_seen_at has data
    present_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Test issue for present member",
      status: "open",
      issue_created_at: 2.hours.ago,
      issue_updated_at: 30.seconds.ago
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

  test "should sync audit members in active audit sessions when team is synced" do
    service = Github::TeamSyncService.new(@team)

    # Create an active audit session with existing audit members
    audit_session = AuditSession.create!(
      name: "Test Audit",
      status: "active",
      organization: @team.organization,
      user: users(:one),
      team: @team
    )

    # Create existing team members and audit members
    existing_member = @team.team_members.create!(
      github_login: "existing_user",
      name: "Existing User",
      active: true
    )

    audit_session.audit_members.create!(
      team_member: existing_member,
      access_validated: true
    )

    # Mock API client that returns existing member plus a new one
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "existing_user",
          name: "Existing User",
          avatar_url: "https://github.com/existing_user.png",
          maintainer_role: false
        },
        {
          github_login: "new_user",
          name: "New User",
          avatar_url: "https://github.com/new_user.png",
          maintainer_role: true
        }
      ]
    end

    def mock_api_client.user_details(username)
      nil
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    # Sync team members
    service.sync_team_members

    # Check that audit session now has both members
    audit_session.reload
    assert_equal 2, audit_session.audit_members.count

    # Check that new audit member was created with correct defaults
    new_audit_member = audit_session.audit_members.joins(:team_member)
                                  .find_by(team_members: { github_login: "new_user" })
    assert_not_nil new_audit_member
    assert_nil new_audit_member.access_validated
    assert_not new_audit_member.removed

    # Check that existing audit member preserved its validation status
    existing_audit_member = audit_session.audit_members.find_by(team_member: existing_member)
    assert existing_audit_member.access_validated
  end

  test "should mark audit members as removed when team member becomes inactive" do
    service = Github::TeamSyncService.new(@team)

    # Create audit session with members
    audit_session = AuditSession.create!(
      name: "Test Audit",
      status: "active",
      organization: @team.organization,
      user: users(:one),
      team: @team
    )

    # Create team members - one will stay, one will be removed
    staying_member = @team.team_members.create!(
      github_login: "staying_user",
      name: "Staying User",
      active: true
    )

    leaving_member = @team.team_members.create!(
      github_login: "leaving_user",
      name: "Leaving User",
      active: true
    )

    # Create corresponding audit members
    staying_audit_member = audit_session.audit_members.create!(
      team_member: staying_member,
      access_validated: true,
      removed: false
    )

    leaving_audit_member = audit_session.audit_members.create!(
      team_member: leaving_member,
      access_validated: false,
      removed: false
    )

    # Mock API that only returns staying member
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "staying_user",
          name: "Staying User",
          avatar_url: "https://github.com/staying_user.png",
          maintainer_role: false
        }
      ]
    end

    def mock_api_client.user_details(username)
      nil
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    # Sync team members
    service.sync_team_members

    # Check that leaving member is marked as inactive in team
    leaving_member.reload
    assert_not leaving_member.active

    # Check that corresponding audit member is marked as removed
    leaving_audit_member.reload
    assert leaving_audit_member.removed

    # Check that staying audit member is unchanged
    staying_audit_member.reload
    assert_not staying_audit_member.removed
    assert staying_audit_member.access_validated
  end

  test "should only sync audit members for active and draft audit sessions" do
    service = Github::TeamSyncService.new(@team)

    # Create audit sessions in different statuses
    active_audit = AuditSession.create!(
      name: "Active Audit",
      status: "active",
      organization: @team.organization,
      user: users(:one),
      team: @team
    )

    draft_audit = AuditSession.create!(
      name: "Draft Audit",
      status: "draft",
      organization: @team.organization,
      user: users(:one),
      team: @team
    )

    completed_audit = AuditSession.create!(
      name: "Completed Audit",
      status: "completed",
      organization: @team.organization,
      user: users(:one),
      team: @team
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.fetch_team_members(team_slug)
      [
        {
          github_login: "test_user",
          name: "Test User",
          avatar_url: "https://github.com/test_user.png",
          maintainer_role: false
        }
      ]
    end

    def mock_api_client.user_details(username)
      nil
    end

    service.instance_variable_set(:@api_client, mock_api_client)

    # Sync team members
    service.sync_team_members

    # Check that only active and draft audits have audit members synced
    assert_equal 1, active_audit.audit_members.count
    assert_equal 1, draft_audit.audit_members.count
    assert_equal 0, completed_audit.audit_members.count
  end
end
