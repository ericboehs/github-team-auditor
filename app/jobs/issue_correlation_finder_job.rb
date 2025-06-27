class IssueCorrelationFinderJob < ApplicationJob
  include TurboBroadcasting

  queue_as :default

  # Retry on transient errors but not on permanent failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    # Don't retry on configuration errors
    raise error if error.is_a?(Github::GraphqlClient::ConfigurationError)

    # Log retry attempt
    Rails.logger.warn "Issue correlation job retrying due to: #{error.message}"
  end

  # Don't retry on configuration errors
  discard_on Github::GraphqlClient::ConfigurationError

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

    # Update team members table with new first/last seen data
    broadcast_team_members_update

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
    # Use the batch GraphQL approach which is much faster
    @correlation_service.find_correlations_for_team
  end

  def broadcast_team_members_update
    # Reload team to ensure fresh data, then get members with issue correlations
    @team.reload
    team_members = @team.team_members.includes(:issue_correlations).current.order(:github_login)
    
    # Force reload of each team member to ensure fresh association data after correlation updates
    team_members.each(&:reload)

    # Broadcast updated team members table to replace the existing one
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{@team.id}",
      target: "team-members-content",
      partial: "teams/team_members_table",
      locals: { team_members: team_members, team: @team }
    )

    Rails.logger.info "Broadcasted team members table update for team #{@team.id}"
  end
end
