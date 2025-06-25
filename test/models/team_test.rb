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

  test "effective_search_terms should return search_terms when present" do
    @team.search_terms = "platform access"
    assert_equal "platform access", @team.effective_search_terms
  end

  test "effective_search_terms should return default when blank" do
    @team.search_terms = ""
    assert_equal "access", @team.effective_search_terms

    @team.search_terms = nil
    assert_equal "access", @team.effective_search_terms
  end

  test "effective_exclusion_terms should return exclusion_terms when present" do
    @team.exclusion_terms = "temporary"
    assert_equal "temporary", @team.effective_exclusion_terms
  end

  test "effective_exclusion_terms should return empty string when blank" do
    @team.exclusion_terms = ""
    assert_equal "", @team.effective_exclusion_terms

    @team.exclusion_terms = nil
    assert_equal "", @team.effective_exclusion_terms
  end

  test "effective_search_repository should return search_repository when present" do
    @team.search_repository = "custom-org/custom-repo"
    assert_equal "custom-org/custom-repo", @team.effective_search_repository
  end

  test "effective_search_repository should return default when blank" do
    @team.search_repository = ""
    assert_equal "#{@team.organization.github_login}/va.gov-team", @team.effective_search_repository

    @team.search_repository = nil
    assert_equal "#{@team.organization.github_login}/va.gov-team", @team.effective_search_repository
  end
end
