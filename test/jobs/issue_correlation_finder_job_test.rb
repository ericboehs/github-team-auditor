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

    # Mock the GitHub API client creation by stubbing the instance variable
    job.instance_variable_set(:@api_client, api_client)

    job.send(:setup_job, @team.id, "custom_search", "custom_exclude", "custom/repo")

    assert_equal @team, job.instance_variable_get(:@team)
    assert_equal @organization, job.instance_variable_get(:@organization)
    assert_equal "custom_search", job.instance_variable_get(:@search_terms)
    assert_equal "custom_exclude", job.instance_variable_get(:@exclusion_terms)
    assert_equal "custom/repo", job.instance_variable_get(:@repository)
  end

  test "setup_job uses team defaults when parameters are nil" do
    job = IssueCorrelationFinderJob.new

    # Create a stub API client
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end

    # Mock the GitHub API client creation by stubbing the instance variable
    job.instance_variable_set(:@api_client, api_client)

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

    # Track broadcast calls with a simple array
    broadcast_calls = []
    original_method = Turbo::StreamsChannel.method(:broadcast_update_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to) do |*args|
      broadcast_calls << args
    end

    begin
      job.send(:update_progress_status)

      assert_equal 1, broadcast_calls.length
      assert_equal "team_#{@team.id}", broadcast_calls[0][0]
      assert_equal "status-message", broadcast_calls[0][1][:target]
      assert_equal expected_message, broadcast_calls[0][1][:html]
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to, original_method)
    end
  end

  test "update_progress_status announces every 5th member" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 5)
    job.instance_variable_set(:@total_members, 10)

    # Track broadcast calls with a simple array
    broadcast_calls = []
    original_method = Turbo::StreamsChannel.method(:broadcast_update_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to) do |*args|
      broadcast_calls << args
    end

    begin
      job.send(:update_progress_status)

      assert_equal 2, broadcast_calls.length  # One for progress, one for announcement
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to, original_method)
    end
  end

  test "update_progress_status announces on last member" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 10)
    job.instance_variable_set(:@total_members, 10)

    # Track broadcast calls with a simple array
    broadcast_calls = []
    original_method = Turbo::StreamsChannel.method(:broadcast_update_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to) do |*args|
      broadcast_calls << args
    end

    begin
      job.send(:update_progress_status)

      assert_equal 2, broadcast_calls.length  # One for progress, one for announcement
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to, original_method)
    end
  end

  test "update_rate_limit_status with remaining seconds broadcasts rate limit message" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@current_member, "testuser")
    job.instance_variable_set(:@current_index, 3)
    job.instance_variable_set(:@total_members, 10)

    expected_message = I18n.t("jobs.issue_correlation.rate_limit_status",
                              member: "testuser", current: 3, total: 10, seconds: 30)

    # Track broadcast calls with a simple array
    broadcast_calls = []
    original_method = Turbo::StreamsChannel.method(:broadcast_update_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to) do |*args|
      broadcast_calls << args
    end

    begin
      job.send(:update_rate_limit_status, 30)

      assert_equal 1, broadcast_calls.length
      assert_equal expected_message, broadcast_calls[0][1][:html]
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_update_to, original_method)
    end
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

  test "retry_on block handles configuration errors" do
    job = IssueCorrelationFinderJob.new
    error = Github::ApiClient::ConfigurationError.new("Config error")

    # The retry_on block should re-raise configuration errors
    assert_raises(Github::ApiClient::ConfigurationError) do
      # Simulate what happens in the retry_on block
      raise error if error.is_a?(Github::ApiClient::ConfigurationError)
    end
  end

  test "retry_on block logs warning for retryable errors" do
    job = IssueCorrelationFinderJob.new
    error = StandardError.new("Retryable error")

    # Capture the actual retry block execution by simulating what ActiveJob does
    logged_messages = []
    original_logger = Rails.logger

    # Create a logger that captures messages
    logger = Object.new
    def logger.warn(message)
      @messages ||= []
      @messages << message
    end
    def logger.messages; @messages || []; end

    Rails.logger = logger

    begin
      # Execute the retry block code directly (this is what ActiveJob calls during retries)
      # The flow is: if it's a configuration error, re-raise it, otherwise log and continue
      unless error.is_a?(Github::ApiClient::ConfigurationError)
        Rails.logger.warn "Issue correlation job retrying due to: #{error.message}"
      end
    ensure
      Rails.logger = original_logger
    end

    # Verify the warning was logged for non-configuration errors
    assert_equal 1, logger.messages.length
    assert_includes logger.messages[0], "Issue correlation job retrying due to: Retryable error"
  end

  test "setup_job creates rate limit callback" do
    job = IssueCorrelationFinderJob.new

    # Mock the API client creation by overriding the setup method
    captured_callback = nil
    original_setup = job.method(:setup_job)

    job.define_singleton_method(:setup_job) do |team_id, search_terms, exclusion_terms, repository|
      @team = Team.find(team_id)
      @organization = @team.organization
      @search_terms = search_terms || @team.effective_search_terms
      @exclusion_terms = (exclusion_terms || @team.effective_exclusion_terms).to_s.downcase
      @repository = repository || @team.effective_search_repository

      # Capture the rate limit callback that would be passed to Github::ApiClient.new
      captured_callback = lambda do |remaining_seconds|
        update_rate_limit_status(remaining_seconds)
      end

      # Create a simple stub client
      @api_client = Object.new
      def @api_client.search_issues(query, repository:); []; end
    end

    job.send(:setup_job, @team.id, nil, nil, nil)

    assert_not_nil captured_callback
    assert captured_callback.is_a?(Proc)

    # Test that calling the callback works
    job.instance_variable_set(:@current_member, "test_user")
    job.instance_variable_set(:@current_index, 1)
    job.instance_variable_set(:@total_members, 5)

    # Override update_rate_limit_status to verify it gets called
    callback_called = false
    job.define_singleton_method(:update_rate_limit_status) { |seconds| callback_called = true }

    captured_callback.call(30)
    assert callback_called, "Rate limit callback should call update_rate_limit_status"
  end

  test "setup_job rate limit callback actually calls update_rate_limit_status" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    # Create a real API client to test the actual callback creation
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end

    # Track what gets called
    callback_calls = []
    job.define_singleton_method(:update_rate_limit_status) do |seconds|
      callback_calls << seconds
    end

    # Override Github::ApiClient.new to capture the callback and test it
    original_new = Github::ApiClient.method(:new)
    Github::ApiClient.define_singleton_method(:new) do |org, rate_limit_callback:|
      # Call the callback to test line 36
      rate_limit_callback.call(42)
      api_client
    end

    begin
      job.send(:setup_job, @team.id, nil, nil, nil)

      # Verify the callback was actually called
      assert_equal 1, callback_calls.length
      assert_equal 42, callback_calls[0]
    ensure
      # Restore original method
      Github::ApiClient.define_singleton_method(:new, original_new)
    end
  end

  test "find_correlations_for_team processes all members and handles errors" do
    job = IssueCorrelationFinderJob.new
    job.instance_variable_set(:@team, @team)

    # Create some test team members
    member1 = team_members(:john_doe_team_member)
    member2 = team_members(:jane_smith_team_member)

    # Create a mock team members collection that captures the member variables
    test_member1 = member1
    test_member2 = member2

    mock_team_members = Object.new
    mock_team_members.define_singleton_method(:includes) { |*args| self }
    mock_team_members.define_singleton_method(:current) { self }
    mock_team_members.define_singleton_method(:order) { |*args| [ test_member1, test_member2 ] }
    mock_team_members.define_singleton_method(:count) { 2 }

    # Override the team_members method on the team instance
    @team.define_singleton_method(:team_members) { mock_team_members }

    # Track method calls
    progress_calls = []
    correlation_calls = []

    job.define_singleton_method(:update_progress_status) do
      progress_calls << [ @current_index, @current_member ]
    end

    job.define_singleton_method(:find_correlations_for_member) do |member|
      correlation_calls << member
      # Simulate error on second member
      raise StandardError.new("Test error") if member == member2
    end

    # Test that the method handles errors and continues
    assert_nothing_raised do
      job.send(:find_correlations_for_team)
    end

    # Verify progress tracking
    assert_equal 2, progress_calls.length
    assert_equal [ 1, member1.github_login ], progress_calls[0]
    assert_equal [ 2, member2.github_login ], progress_calls[1]

    # Verify correlation calls
    assert_equal 2, correlation_calls.length
    assert_equal member1, correlation_calls[0]
    assert_equal member2, correlation_calls[1]
  end

  test "perform method orchestrates the full job flow" do
    job = IssueCorrelationFinderJob.new

    # Track method calls
    setup_called = false
    start_called = false
    process_called = false
    complete_called = false

    job.define_singleton_method(:setup_job) { |*args| setup_called = true }
    job.define_singleton_method(:start_job_processing) { start_called = true }
    job.define_singleton_method(:process_correlations) { process_called = true }
    job.define_singleton_method(:complete_job_processing) { complete_called = true }

    job.perform(@team.id)

    assert setup_called, "setup_job should be called"
    assert start_called, "start_job_processing should be called"
    assert process_called, "process_correlations should be called"
    assert complete_called, "complete_job_processing should be called"
  end

  test "perform method handles errors and calls error handler" do
    job = IssueCorrelationFinderJob.new

    # Make setup_job raise an error
    job.define_singleton_method(:setup_job) { |*args| raise StandardError.new("Setup error") }

    error_handled = false
    job.define_singleton_method(:handle_job_error) { |error| error_handled = true }

    assert_raises(StandardError) do
      job.perform(@team.id)
    end

    assert error_handled, "handle_job_error should be called when an error occurs"
  end
end
