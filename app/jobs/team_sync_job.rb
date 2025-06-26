class TeamSyncJob < ApplicationJob
  include TurboBroadcasting

  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on Github::ApiClient::ConfigurationError

  def perform(team_id)
    @team = Team.find(team_id)
    start_sync_processing
    sync_results = perform_team_sync
    complete_sync_processing(sync_results)
    sync_results
  rescue ActiveRecord::RecordNotFound => e
    handle_team_not_found_error(e)
    raise
  rescue StandardError => e
    handle_sync_error(e)
    raise
  end

  private

  def start_sync_processing
    Rails.logger.info "Starting team sync for team: #{@team.name}"
    @team.start_sync_job!

    # Broadcast job started
    broadcast_job_started(@team, "jobs.team_sync.syncing", "jobs.team_sync.started_announcement")
  end

  def perform_team_sync
    # Sync team members to team_members table
    sync_service = Github::TeamSyncService.new(@team)
    sync_service.sync_team_members
  end

  def complete_sync_processing(results)
    # Complete the job first - this clears sync_status
    @team.complete_sync_job!

    # Create completion message
    message = I18n.t("jobs.team_sync.completed_success", new_count: results[:new_members], updated_count: results[:updated])

    # Broadcast job completion (handles flash message, status banner, dropdown, team card)
    broadcast_job_completed(@team, message)

    # Announce completion to screen readers
    broadcast_live_announcement(@team, I18n.t("jobs.team_sync.completed_announcement", team_name: @team.name, new_count: results[:new_members], updated_count: results[:updated]))

    # Broadcast team-specific updates
    broadcast_team_sync_updates(@team, results)

    Rails.logger.info "Broadcasted sync completion for team #{@team.id}: #{message}"
    Rails.logger.info "Team sync completed for team: #{@team.name} - #{results[:total]} members (#{results[:new_members]} new, #{results[:updated]} updated)"
  end

  def handle_team_not_found_error(error)
    Rails.logger.error "Team not found: #{error.message}"
    @team&.update!(sync_status: "failed")
  end

  def handle_sync_error(error)
    Rails.logger.error "Team sync failed: #{error.message}"
    @team&.update!(sync_status: "failed")

    # Broadcast error message to user
    broadcast_job_error(@team, error) if @team
  end

  def broadcast_team_sync_updates(team, results)
    # Broadcast updated team stats
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{team.id}",
      target: "team-stats",
      partial: "teams/team_stats",
      locals: {
        total_members_count: results[:total],
        validated_members_count: 0,
        maintainer_members_count: team.team_members.where(maintainer_role: true).count,
        team: team
      }
    )

    # Update last synced info
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{team.id}",
      target: "last-synced",
      partial: "teams/last_synced",
      locals: { last_synced_at: team.last_synced_at, last_issue_correlation_at: team.issue_correlation_completed_at }
    )

    # Update team members table to replace empty state with actual members
    team_members = team.team_members.includes(:issue_correlations).current.order(:github_login)
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{team.id}",
      target: "team-members-content",
      partial: "teams/team_members_table",
      locals: { team_members: team_members, team: team }
    )
  end
end
