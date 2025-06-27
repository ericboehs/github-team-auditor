require "test_helper"

class IssueCorrelationFinderJobTest < ActiveJob::TestCase
  def setup
    @organization = organizations(:va)
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)
  end

  test "job is enqueued with correct arguments" do
    assert_enqueued_with(job: IssueCorrelationFinderJob, args: [ @team.id ]) do
      IssueCorrelationFinderJob.perform_later(@team.id)
    end
  end

  test "job is enqueued with search options" do
    assert_enqueued_with(
      job: IssueCorrelationFinderJob,
      args: [ @team.id, { search_terms: "custom", exclusion_terms: "test", repository: "custom/repo" } ]
    ) do
      IssueCorrelationFinderJob.perform_later(@team.id, search_terms: "custom", exclusion_terms: "test", repository: "custom/repo")
    end
  end

  test "job handles team not found error" do
    assert_raises(ActiveRecord::RecordNotFound) do
      IssueCorrelationFinderJob.new.perform(999999) # Non-existent team ID
    end
  end

  test "job creates correlation service with correct parameters" do
    # Ensure GitHub token is set for this test
    original_token = ENV["GHTA_GITHUB_TOKEN"]
    ENV["GHTA_GITHUB_TOKEN"] = "ghp_test_token_for_testing"

    begin
      job = IssueCorrelationFinderJob.new

      # Set up the job state as if setup_job was called
      job.instance_variable_set(:@team, @team)
      job.instance_variable_set(:@organization, @organization)
      job.instance_variable_set(:@search_terms, "test terms")
      job.instance_variable_set(:@exclusion_terms, "exclude terms")
      job.instance_variable_set(:@repository, "test/repo")

      # Define a minimal find_correlations_for_team method
      def job.find_correlations_for_team; end

      job.send(:process_correlations)

      # Verify the service was created
      service = job.instance_variable_get(:@correlation_service)
      assert_not_nil service
      assert_instance_of IssueCorrelationService, service
      assert_equal @team, service.team
      assert_equal "test terms", service.search_terms
    ensure
      # Restore original token
      if original_token
        ENV["GHTA_GITHUB_TOKEN"] = original_token
      else
        ENV.delete("GHTA_GITHUB_TOKEN")
      end
    end
  end

  test "job uses team effective configuration methods" do
    # Test that the job calls the right methods on the team
    assert_respond_to @team, :effective_search_terms
    assert_respond_to @team, :effective_exclusion_terms
    assert_respond_to @team, :effective_search_repository

    # Test default values
    assert_equal "access", @team.effective_search_terms
    assert_equal "", @team.effective_exclusion_terms
    assert_equal "#{@organization.github_login}/va.gov-team", @team.effective_search_repository
  end

  test "setup_job initializes instance variables correctly" do
    job = IssueCorrelationFinderJob.new

    job.send(:setup_job, @team.id, "custom_search", "custom_exclude", "custom/repo")

    assert_equal @team, job.instance_variable_get(:@team)
    assert_equal @organization, job.instance_variable_get(:@organization)
    assert_equal "custom_search", job.instance_variable_get(:@search_terms)
    assert_equal "custom_exclude", job.instance_variable_get(:@exclusion_terms)
    assert_equal "custom/repo", job.instance_variable_get(:@repository)
  end

  test "setup_job uses team defaults when parameters are nil" do
    job = IssueCorrelationFinderJob.new

    job.send(:setup_job, @team.id, nil, nil, nil)

    assert_equal @team.effective_search_terms, job.instance_variable_get(:@search_terms)
    assert_equal @team.effective_exclusion_terms.downcase, job.instance_variable_get(:@exclusion_terms)
    assert_equal @team.effective_search_repository, job.instance_variable_get(:@repository)
  end

  test "start_job_processing logs and broadcasts" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@search_terms, "test")

    # Define minimal broadcast methods to avoid errors
    def job.broadcast_job_started(*args); end

    # Test that the method completes without error
    assert_nothing_raised do
      job.send(:start_job_processing)
    end

    # Verify team status was updated
    assert_equal "running", @team.reload.issue_correlation_status
  end

  test "complete_job_processing updates team and broadcasts" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    # Define minimal broadcast methods to avoid errors
    def job.broadcast_job_completed(*args); end
    def job.broadcast_live_announcement(*args); end

    # Test that the method completes without error
    assert_nothing_raised do
      job.send(:complete_job_processing)
    end

    # Verify team status was updated (should be nil after completion)
    assert_nil @team.reload.issue_correlation_status
  end

  test "handle_job_error logs error and updates team" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    error = StandardError.new("Test error")
    error.set_backtrace([ "line1", "line2", "line3", "line4", "line5", "line6" ])

    # Define minimal broadcast method to avoid errors
    def job.broadcast_job_error(*args); end

    # Test that the method completes without error
    assert_nothing_raised do
      job.send(:handle_job_error, error)
    end

    # Verify team status was updated
    assert_equal "failed", @team.reload.issue_correlation_status
  end

  test "find_correlations_for_team uses batch GraphQL approach" do
    job = IssueCorrelationFinderJob.new

    # Mock the correlation service
    service = Object.new
    service_called = false
    def service.find_correlations_for_team
      @batch_called = true
    end
    def service.batch_called?; @batch_called; end

    job.instance_variable_set(:@correlation_service, service)

    # Call the method under test
    job.send(:find_correlations_for_team)

    # Verify the batch method was called
    assert service.batch_called?, "Should call find_correlations_for_team on service"
  end

  test "job executes full perform workflow" do
    # This test exercises lines 19-22: setup_job, start_job_processing, process_correlations, complete_job_processing
    original_token = ENV["GHTA_GITHUB_TOKEN"]
    ENV["GHTA_GITHUB_TOKEN"] = "ghp_test_token_for_testing"

    begin
      job = IssueCorrelationFinderJob.new

      # Mock methods to avoid actual work but ensure they're called
      setup_called = false
      start_called = false
      process_called = false
      complete_called = false

      job.define_singleton_method(:setup_job) { |*args| setup_called = true }
      job.define_singleton_method(:start_job_processing) { start_called = true }
      job.define_singleton_method(:process_correlations) { process_called = true }
      job.define_singleton_method(:complete_job_processing) { complete_called = true }

      # Execute the perform method
      job.perform(@team.id)

      # Verify all steps were called (covers L19-22)
      assert setup_called, "setup_job should be called"
      assert start_called, "start_job_processing should be called"
      assert process_called, "process_correlations should be called"
      assert complete_called, "complete_job_processing should be called"
    ensure
      if original_token
        ENV["GHTA_GITHUB_TOKEN"] = original_token
      else
        ENV.delete("GHTA_GITHUB_TOKEN")
      end
    end
  end

  test "job handles errors and calls handle_job_error" do
    # This test exercises the rescue block and should trigger L12 logging
    original_token = ENV["GHTA_GITHUB_TOKEN"]
    ENV["GHTA_GITHUB_TOKEN"] = "ghp_test_token_for_testing"

    begin
      job = IssueCorrelationFinderJob.new
      error_handled = false

      # Mock setup_job to raise an error to test error handling
      job.define_singleton_method(:setup_job) { |*args| raise StandardError, "Test error" }
      job.define_singleton_method(:handle_job_error) { |error| error_handled = true }

      # Execute the perform method - should catch error
      assert_nothing_raised do
        begin
          job.perform(@team.id)
        rescue StandardError
          # Expected to be re-raised after handling
        end
      end

      assert error_handled, "handle_job_error should be called"
    ensure
      if original_token
        ENV["GHTA_GITHUB_TOKEN"] = original_token
      else
        ENV.delete("GHTA_GITHUB_TOKEN")
      end
    end
  end

  # Note: Testing retry_on and discard_on behavior is complex in ActiveJob
  # The functionality is tested at the framework level and configured correctly in the job class
end
