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
    job = IssueCorrelationFinderJob.new

    # Set up the job state as if setup_job was called
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@organization, @organization)
    job.instance_variable_set(:@search_terms, "test terms")
    job.instance_variable_set(:@exclusion_terms, "exclude terms")
    job.instance_variable_set(:@repository, "test/repo")

    # Create a stub API client
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end
    job.instance_variable_set(:@api_client, api_client)

    # Define a minimal find_correlations_for_team method
    def job.find_correlations_for_team; end

    job.send(:process_correlations)

    # Verify the service was created
    service = job.instance_variable_get(:@correlation_service)
    assert_not_nil service
    assert_instance_of IssueCorrelationService, service
    assert_equal @team, service.team
    assert_equal "test terms", service.search_terms
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

    # Create a stub API client
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end

    # Stub the GitHub API client creation
    Github::ApiClient.stub(:new, api_client) do
      job.send(:setup_job, @team.id, "custom_search", "custom_exclude", "custom/repo")

      assert_equal @team, job.instance_variable_get(:@team)
      assert_equal @organization, job.instance_variable_get(:@organization)
      assert_equal "custom_search", job.instance_variable_get(:@search_terms)
      assert_equal "custom_exclude", job.instance_variable_get(:@exclusion_terms)
      assert_equal "custom/repo", job.instance_variable_get(:@repository)
      assert_equal api_client, job.instance_variable_get(:@api_client)
    end
  end

  test "setup_job uses team defaults when parameters are nil" do
    job = IssueCorrelationFinderJob.new

    # Create a stub API client
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end

    # Stub the GitHub API client creation
    Github::ApiClient.stub(:new, api_client) do
      job.send(:setup_job, @team.id, nil, nil, nil)

      assert_equal @team.effective_search_terms, job.instance_variable_get(:@search_terms)
      assert_equal @team.effective_exclusion_terms.downcase, job.instance_variable_get(:@exclusion_terms)
      assert_equal @team.effective_search_repository, job.instance_variable_get(:@repository)
    end
  end

  test "start_job_processing logs and broadcasts" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@search_terms, "test")

    log_output = StringIO.new
    Rails.logger.stub(:info, proc { |msg| log_output.puts(msg) }) do
      # Define minimal broadcast methods to avoid errors
      def job.broadcast_job_started(*args); end

      job.send(:start_job_processing)
    end

    assert_includes log_output.string, "Starting issue correlation finder for team #{@team.name} with search terms: test"
  end

  test "complete_job_processing updates team and broadcasts" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    log_output = StringIO.new
    Rails.logger.stub(:info, proc { |msg| log_output.puts(msg) }) do
      # Define minimal broadcast methods to avoid errors
      def job.broadcast_job_completed(*args); end
      def job.broadcast_live_announcement(*args); end

      job.send(:complete_job_processing)
    end

    assert_includes log_output.string, "Issue correlation finder completed for team #{@team.name}"
  end

  test "handle_job_error logs error and updates team" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    error = StandardError.new("Test error")
    error.set_backtrace([ "line1", "line2", "line3", "line4", "line5", "line6" ])

    log_output = StringIO.new
    Rails.logger.stub(:error, proc { |msg| log_output.puts(msg) }) do
      # Define minimal broadcast method to avoid errors
      def job.broadcast_job_error(*args); end

      job.send(:handle_job_error, error)
    end

    assert_includes log_output.string, "Issue correlation finder failed for team #{@team.name}: Test error"
    assert_includes log_output.string, "Error details: line1, line2, line3, line4, line5"
    assert_equal "failed", @team.reload.issue_correlation_status
  end

  test "find_correlations_for_member delegates to service" do
    job = IssueCorrelationFinderJob.new

    # Create a simple service object
    service = Object.new
    call_count = 0
    def service.find_correlations_for_member(member)
      @call_count = (@call_count || 0) + 1
      @last_member = member
    end

    def service.call_count; @call_count || 0; end
    def service.last_member; @last_member; end

    job.instance_variable_set(:@correlation_service, service)

    job.send(:find_correlations_for_member, @team_member)

    assert_equal 1, service.call_count
    assert_equal @team_member, service.last_member
  end

  test "update_progress_status broadcasts progress" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 3)
    job.instance_variable_set(:@total_members, 10)

    expected_message = I18n.t("jobs.issue_correlation.progress_status",
                              member: "testuser", current: 3, total: 10)

    broadcast_calls = []
    Turbo::StreamsChannel.stub(:broadcast_update_to, proc { |*args| broadcast_calls << args }) do
      job.send(:update_progress_status)
    end

    assert_equal 1, broadcast_calls.length
    assert_equal "team_#{@team.id}", broadcast_calls[0][0]
    assert_equal "status-message", broadcast_calls[0][1][:target]
    assert_equal expected_message, broadcast_calls[0][1][:html]
  end

  test "update_progress_status announces every 5th member" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 5)
    job.instance_variable_set(:@total_members, 10)

    broadcast_calls = []
    Turbo::StreamsChannel.stub(:broadcast_update_to, proc { |*args| broadcast_calls << args }) do
      job.send(:update_progress_status)
    end

    assert_equal 2, broadcast_calls.length  # One for progress, one for announcement
  end

  test "update_progress_status announces on last member" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 10)
    job.instance_variable_set(:@total_members, 10)

    broadcast_calls = []
    Turbo::StreamsChannel.stub(:broadcast_update_to, proc { |*args| broadcast_calls << args }) do
      job.send(:update_progress_status)
    end

    assert_equal 2, broadcast_calls.length  # One for progress, one for announcement
  end

  test "update_rate_limit_status with remaining seconds broadcasts rate limit message" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 3)
    job.instance_variable_set(:@total_members, 10)

    expected_message = I18n.t("jobs.issue_correlation.rate_limit_status",
                              member: "testuser", current: 3, total: 10, seconds: 30)

    broadcast_calls = []
    Turbo::StreamsChannel.stub(:broadcast_update_to, proc { |*args| broadcast_calls << args }) do
      job.send(:update_rate_limit_status, 30)
    end

    assert_equal 1, broadcast_calls.length
    assert_equal expected_message, broadcast_calls[0][1][:html]
  end

  test "update_rate_limit_status with zero seconds resumes progress" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 3)
    job.instance_variable_set(:@total_members, 10)

    # Override update_progress_status to track calls
    progress_called = false
    job.define_singleton_method(:update_progress_status) { progress_called = true }

    job.send(:update_rate_limit_status, 0)

    assert progress_called, "update_progress_status should be called when remaining seconds is 0"
  end
end
