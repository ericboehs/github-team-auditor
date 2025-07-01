require "test_helper"
require "minitest/mock"

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
    # Mock the sync service to prevent actual API calls
    mock_service = Minitest::Mock.new
    mock_service.expect :sync_team_members, { total: 0, new_members: 0, updated: 0 }

    Github::TeamSyncService.stub :new, mock_service do
      @team.sync_from_github_now!
    end

    # Should update sync status to running initially, then complete
    @team.reload
    assert_nil @team.sync_status # Should be cleared after completion
    assert_not_nil @team.sync_completed_at

    mock_service.verify
  end

  test "current_job_status returns sync status when sync_status is not running" do
    @team.update!(sync_status: "failed")
    assert_equal "failed", @team.current_job_status
  end

  test "current_job_status returns issue correlation status when issue_correlation_status is not running" do
    @team.update!(issue_correlation_status: "failed")
    assert_equal "failed", @team.current_job_status
  end

  test "current_job_status handles issue correlation with non-running status" do
    # Only issue correlation is running but status is not "running"
    @team.update!(sync_status: nil, issue_correlation_status: "completed")
    # This should trigger the branch where issue_correlation_status != "running" on line 88
    assert_equal "completed", @team.current_job_status
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

  test "current_job_status returns issue correlation status when not running" do
    # Test line 82: issue_correlation_status != "running"
    @team.update!(issue_correlation_status: "failed")

    assert_equal "failed", @team.current_job_status
  end

  test "complete_job! with completion_field sets timestamp" do
    # Test line 99: completion_field branch
    freeze_time = Time.current
    Time.stub :current, freeze_time do
      @team.send(:complete_job!, :sync, completion_field: :sync_completed_at)
    end

    assert_nil @team.sync_status
    assert_equal freeze_time, @team.sync_completed_at
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

  test "sync_running? should return true when sync_status is running" do
    @team.update!(sync_status: "running")
    assert @team.sync_running?

    @team.update!(sync_status: nil)
    assert_not @team.sync_running?
  end

  test "issue_correlation_running? should return true when issue_correlation_status is running" do
    @team.update!(issue_correlation_status: "running")
    assert @team.issue_correlation_running?

    @team.update!(issue_correlation_status: nil)
    assert_not @team.issue_correlation_running?
  end

  test "any_jobs_running? should return true when any job is running" do
    @team.update!(sync_status: "running", issue_correlation_status: nil)
    assert @team.any_jobs_running?

    @team.update!(sync_status: nil, issue_correlation_status: "running")
    assert @team.any_jobs_running?

    @team.update!(sync_status: "running", issue_correlation_status: "running")
    assert @team.any_jobs_running?

    @team.update!(sync_status: nil, issue_correlation_status: nil)
    assert_not @team.any_jobs_running?
  end

  test "current_job_status should return appropriate messages" do
    @team.update!(sync_status: "running", issue_correlation_status: "running")
    assert_equal "running", @team.current_job_status

    @team.update!(sync_status: "running", issue_correlation_status: nil)
    assert_equal "Syncing team members from GitHub...", @team.current_job_status

    @team.update!(sync_status: nil, issue_correlation_status: "Finding issues for testuser (1/5)...")
    assert_equal "Finding issues for testuser (1/5)...", @team.current_job_status

    @team.update!(sync_status: nil, issue_correlation_status: nil)
    assert_nil @team.current_job_status
  end

  test "start_sync_job! should set sync status" do
    @team.start_sync_job!

    assert_equal "running", @team.sync_status
  end

  test "complete_sync_job! should clear sync status and set sync_completed_at" do
    @team.update!(sync_status: "running")
    @team.complete_sync_job!

    assert_nil @team.sync_status
    assert_not_nil @team.sync_completed_at
    assert_in_delta Time.current, @team.sync_completed_at, 1.second
  end

  test "start_issue_correlation_job! should set issue correlation status" do
    @team.start_issue_correlation_job!

    assert_equal "running", @team.issue_correlation_status
  end

  test "complete_issue_correlation_job! should clear issue correlation status and set timestamp" do
    @team.update!(issue_correlation_status: "running")
    @team.complete_issue_correlation_job!

    assert_nil @team.issue_correlation_status
    assert_not_nil @team.issue_correlation_completed_at
    assert_in_delta Time.current, @team.issue_correlation_completed_at, 1.second
  end

  test "any_jobs_running? should only include running jobs" do
    @team.update!(sync_status: nil, issue_correlation_status: nil)
    assert_not @team.any_jobs_running?

    @team.update!(sync_status: "running")
    assert @team.any_jobs_running?

    @team.update!(sync_status: nil, issue_correlation_status: "running")
    assert @team.any_jobs_running?

    @team.update!(sync_status: "running", issue_correlation_status: "running")
    assert @team.any_jobs_running?

    @team.update!(sync_status: nil, issue_correlation_status: nil)
    assert_not @team.any_jobs_running?
  end

  test "current_job_status should return appropriate messages for running jobs" do
    @team.update!(sync_status: "running", issue_correlation_status: "Hit GitHub's rate limit. Waiting 30 seconds...")
    assert_equal "Hit GitHub's rate limit. Waiting 30 seconds...", @team.current_job_status

    @team.update!(sync_status: "running", issue_correlation_status: nil)
    assert_equal "Syncing team members from GitHub...", @team.current_job_status

    @team.update!(sync_status: nil, issue_correlation_status: "Finding issues for testuser (2/5)...")
    assert_equal "Finding issues for testuser (2/5)...", @team.current_job_status

    @team.update!(sync_status: nil, issue_correlation_status: nil)
    assert_nil @team.current_job_status
  end
end
