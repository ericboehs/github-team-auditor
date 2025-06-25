require "test_helper"
require "minitest/mock"

class TeamSyncJobTest < ActiveJob::TestCase
  setup do
    @team = teams(:platform_security)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "should perform sync with valid team" do
    # Mock the sync service
    mock_service = Minitest::Mock.new
    mock_service.expect :sync_team_members, { total: 5, new_members: 2, updated: 1 }

    Github::TeamSyncService.stub :new, mock_service do
      result = TeamSyncJob.perform_now(@team.id)
      assert_equal({ total: 5, new_members: 2, updated: 1 }, result)
    end

    mock_service.verify

    # Check that team's last_synced_at was updated
    @team.reload
    assert_not_nil @team.last_synced_at
    assert_in_delta Time.current, @team.last_synced_at, 5.seconds
  end

  test "should handle missing team" do
    assert_raises ActiveRecord::RecordNotFound do
      # Use perform_now directly, not with block syntax for job queuing
      job = TeamSyncJob.new
      job.perform(99999)
    end
  end

  test "should update team last_synced_at timestamp" do
    old_timestamp = @team.last_synced_at

    # Mock the sync service
    mock_service = Minitest::Mock.new
    mock_service.expect :sync_team_members, { total: 3, new_members: 0, updated: 1 }

    Github::TeamSyncService.stub :new, mock_service do
      TeamSyncJob.perform_now(@team.id)
    end

    @team.reload
    assert_not_equal old_timestamp, @team.last_synced_at
    assert_in_delta Time.current, @team.last_synced_at, 5.seconds
  end

  test "should be queued in default queue" do
    assert_equal "default", TeamSyncJob.queue_name
  end

  test "should handle sync service errors" do
    # Mock the sync service to raise an error and test the rescue block (lines 26-27)
    mock_service = Minitest::Mock.new
    mock_service.expect :sync_team_members, nil do
      raise StandardError, "Sync failed"
    end

    Github::TeamSyncService.stub :new, mock_service do
      error = assert_raises StandardError do
        job = TeamSyncJob.new
        job.perform(@team.id)
      end

      assert_equal "Sync failed", error.message
    end

    mock_service.verify
  end
end
