class IssueCorrelationFinderJob < ApplicationJob
  include TurboBroadcasting

  queue_as :default

  # Retry on transient errors but not on permanent failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    # Don't retry on configuration errors
    raise error if error.is_a?(Github::ApiClient::ConfigurationError)

    # Log retry attempt
    Rails.logger.warn "Issue correlation job retrying due to: #{error.message}"
  end

  # Don't retry on configuration errors
  discard_on Github::ApiClient::ConfigurationError

  def perform(team_id, search_terms: nil, exclusion_terms: nil, repository: nil)
    setup_job(team_id, search_terms, exclusion_terms, repository)
    start_job_processing
    process_correlations
    complete_job_processing
  rescue StandardError => e
    handle_job_error(e)
    raise
  end

  private

  def setup_job(team_id, search_terms, exclusion_terms, repository)
    @team = Team.find(team_id)
    @organization = @team.organization

    # Create API client with rate limit callback for countdown display
    rate_limit_callback = lambda do |remaining_seconds|
      update_rate_limit_status(remaining_seconds)
    end
    @api_client = @api_client || Github::ApiClient.new(@organization, rate_limit_callback: rate_limit_callback)

    # Use team's search configuration, with fallbacks to parameters or defaults
    @search_terms = search_terms || @team.effective_search_terms
    @exclusion_terms = (exclusion_terms || @team.effective_exclusion_terms).to_s.downcase
    @repository = repository || @team.effective_search_repository
  end

  def start_job_processing
    Rails.logger.info "Starting issue correlation finder for team #{@team.name} with search terms: #{@search_terms}"
    @team.start_issue_correlation_job!

    # Broadcast job started
    broadcast_job_started(@team, "jobs.issue_correlation.finding_issues", "jobs.issue_correlation.started_announcement")
  end

  def process_correlations
    @correlation_service = IssueCorrelationService.new(
      @team,
      api_client: @api_client,
      search_terms: @search_terms,
      exclusion_terms: @exclusion_terms,
      repository: @repository
    )

    find_correlations_for_team
  end

  def complete_job_processing
    # Count the results for a better message
    total_issues = @team.team_members.joins(:issue_correlations).count
    message = I18n.t("jobs.issue_correlation.completed_success", count: total_issues)

    # Complete the job first
    @team.complete_issue_correlation_job!

    # Broadcast job completion (handles flash message, status banner, dropdown, team card)
    broadcast_job_completed(@team, message)

    # Announce completion to screen readers
    broadcast_live_announcement(@team, I18n.t("jobs.issue_correlation.completed_announcement", team_name: @team.name, count: total_issues))

    Rails.logger.info "Broadcasted correlation completion message for team #{@team.id}: #{message}"
    Rails.logger.info "Issue correlation finder completed for team #{@team.name}"
  end

  def handle_job_error(error)
    Rails.logger.error "Issue correlation finder failed for team #{@team&.name}: #{error.message}"
    Rails.logger.error "Error details: #{error.backtrace&.first(5)&.join(', ')}"

    # Mark team as failed and broadcast error message
    @team&.update!(issue_correlation_status: "failed")

    # Broadcast error message to user using shared logic
    broadcast_job_error(@team, error)
  end

  def find_correlations_for_team
    members = @team.team_members.includes(:issue_correlations).current.order(:github_login)
    total_members = members.count
    @current_index = 0

    members.each do |team_member|
      @current_index += 1
      @current_member = team_member.github_login
      @total_members = total_members

      # Update status with current progress
      update_progress_status

      find_correlations_for_member(team_member)
    rescue StandardError => e
      Rails.logger.error "Failed to find correlations for member #{team_member.github_login}: #{e.message}"
      # Continue with other members even if one fails
    end
  end

  def find_correlations_for_member(team_member)
    @correlation_service.find_correlations_for_member(team_member)
  end


  def update_progress_status
    progress_message = I18n.t("jobs.issue_correlation.progress_status", member: @current_member, current: @current_index, total: @total_members)

    # Broadcast only the message text update (keeps spinner spinning smoothly)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "status-message",
      html: progress_message
    )

    # Announce progress to screen readers every 5th member to avoid spam
    if @current_index % 5 == 0 || @current_index == @total_members
      Turbo::StreamsChannel.broadcast_update_to(
        "team_#{@team.id}",
        target: "live-announcements",
        html: I18n.t("jobs.issue_correlation.progress_announcement", current: @current_index, total: @total_members, member: @current_member)
      )
    end
  end

  def update_rate_limit_status(remaining_seconds)
    if remaining_seconds > 0
      # Combine progress and rate limit information
      combined_message = I18n.t("jobs.issue_correlation.rate_limit_status", member: @current_member, current: @current_index, total: @total_members, seconds: remaining_seconds)

      # Broadcast only the message text update (keeps spinner spinning smoothly)
      Turbo::StreamsChannel.broadcast_update_to(
        "team_#{@team.id}",
        target: "status-message",
        html: combined_message
      )
    else
      # Resume with progress information
      update_progress_status
    end
  end
end
