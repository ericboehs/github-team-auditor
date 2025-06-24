require "test_helper"

class TeamTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @team = teams(:platform_security)
  end

  test "should be valid" do
    assert @team.valid?
  end

  test "should require name" do
    @team.name = nil
    assert_not @team.valid?
    assert_includes @team.errors[:name], "can't be blank"
  end

  test "should require github_slug" do
    @team.github_slug = nil
    assert_not @team.valid?
    assert_includes @team.errors[:github_slug], "can't be blank"
  end

  test "should validate github_slug uniqueness within organization" do
    duplicate_team = Team.new(
      organization: @team.organization,
      name: "Different Name",
      github_slug: @team.github_slug
    )
    assert_not duplicate_team.valid?
    assert_includes duplicate_team.errors[:github_slug], "has already been taken"
  end

  test "github_url should return correct URL" do
    expected_url = "https://github.com/orgs/#{@team.organization.github_login}/teams/#{@team.github_slug}"
    assert_equal expected_url, @team.github_url
  end

  test "sync_from_github! should enqueue TeamSyncJob" do
    assert_enqueued_jobs 1, only: TeamSyncJob do
      @team.sync_from_github!
    end
  end

  test "sync_from_github_now! should perform TeamSyncJob immediately" do
    # Mock the job performance since we don't want to actually call GitHub API
    TeamSyncJob.stub :perform_now, true do
      result = @team.sync_from_github_now!
      assert result
    end
  end

  test "active_audit_sessions should return draft and active sessions" do
    active_sessions = @team.active_audit_sessions

    # Both q1_2025_audit and q2_2025_platform_security have status "active"
    assert_equal 2, active_sessions.count
    active_sessions.each do |session|
      assert_includes [ "draft", "active" ], session.status
    end
  end

  test "should have proper associations" do
    assert_respond_to @team, :organization
    assert_respond_to @team, :audit_sessions
    assert_respond_to @team, :team_members
  end

  test "should destroy dependent audit_sessions when team is destroyed" do
    audit_sessions_count = @team.audit_sessions.count
    assert audit_sessions_count > 0

    @team.destroy

    # Check that audit sessions were destroyed
    destroyed_sessions = AuditSession.where(team_id: @team.id)
    assert_empty destroyed_sessions
  end

  test "should destroy dependent team_members when team is destroyed" do
    team_members_count = @team.team_members.count
    assert team_members_count > 0

    @team.destroy

    # Check that team members were destroyed
    destroyed_members = TeamMember.where(team_id: @team.id)
    assert_empty destroyed_members
  end
end
