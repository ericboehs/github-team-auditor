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

    # Check that team's sync_completed_at was updated
    @team.reload
    assert_not_nil @team.sync_completed_at
    assert_in_delta Time.current, @team.sync_completed_at, 5.seconds
  end

  test "should handle missing team" do
    assert_raises ActiveRecord::RecordNotFound do
      # Use perform_now directly, not with block syntax for job queuing
      job = TeamSyncJob.new
      job.perform(99999)
    end
  end

  test "should update team sync_completed_at timestamp" do
    old_timestamp = @team.sync_completed_at

    # Mock the sync service
    mock_service = Minitest::Mock.new
    mock_service.expect :sync_team_members, { total: 3, new_members: 0, updated: 1 }

    Github::TeamSyncService.stub :new, mock_service do
      TeamSyncJob.perform_now(@team.id)
    end

    @team.reload
    assert_not_equal old_timestamp, @team.sync_completed_at
    assert_in_delta Time.current, @team.sync_completed_at, 5.seconds
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

      # Check that team sync_status was set to failed
      @team.reload
      assert_equal "failed", @team.sync_status
    end

    mock_service.verify
  end

  test "handle_team_not_found_error with nil team" do
    # Test line 61: @team&.update! when @team is nil
    job = TeamSyncJob.new
    job.instance_variable_set(:@team, nil)

    error = ActiveRecord::RecordNotFound.new("Team not found")

    # Should not raise error even with nil team
    assert_nothing_raised do
      job.send(:handle_team_not_found_error, error)
    end
  end

  test "handle_sync_error with nil team" do
    # Test lines 66 and 69: @team&.update! and broadcast_job_error when @team is nil
    job = TeamSyncJob.new
    job.instance_variable_set(:@team, nil)

    error = StandardError.new("Sync error")

    # Should not raise error or broadcast when team is nil
    assert_nothing_raised do
      job.send(:handle_sync_error, error)
    end
  end

  test "handle_sync_error with valid team broadcasts error" do
    # Test line 69: broadcast_job_error when @team is present
    job = TeamSyncJob.new
    job.instance_variable_set(:@team, @team)

    # Mock the broadcast method to avoid actual broadcasting
    broadcast_called = false
    job.define_singleton_method(:broadcast_job_error) { |team, error| broadcast_called = true }

    error = StandardError.new("Sync error")

    job.send(:handle_sync_error, error)

    assert broadcast_called, "broadcast_job_error should be called when team is present"
    assert_equal "failed", @team.reload.sync_status
  end
end
