class TeamSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on Github::ApiClient::ConfigurationError

  def perform(team_id)
    team = Team.find(team_id)

    Rails.logger.info "Starting team sync for team: #{team.name}"
    team.start_sync_job!

    # Broadcast sync started to team show page
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "status-banner-container",
      partial: "shared/status_banner",
      locals: { message: "Syncing team members from GitHub...", type: :info, spinner: true }
    )

    # Broadcast syncing state to team index page
    team.reload # Get fresh sync_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "teams_index",
      target: "team-card-#{team.id}",
      partial: "teams/team_card",
      locals: { team: team }
    )

    # Sync team members to team_members table
    sync_service = Github::TeamSyncService.new(team)
    results = sync_service.sync_team_members

    # Complete the job first - this clears sync_status
    team.complete_sync_job!

    # Create completion message
    message = "Team sync completed successfully! Added #{results[:new_members]} new members, updated #{results[:updated]} members."

    # Broadcast completion message via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "flash-messages",
      partial: "shared/turbo_flash_message",
      locals: { message: message, type: :success }
    )

    # Clear status banner by updating the container with empty content
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "status-banner-container",
      html: ""
    )

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

    # Update team card on index page to remove syncing badge
    team.reload # Ensure fresh data
    Turbo::StreamsChannel.broadcast_replace_to(
      "teams_index",
      target: "team-card-#{team.id}",
      partial: "teams/team_card",
      locals: { team: team }
    )

    Rails.logger.info "Broadcasted sync completion for team #{team.id}: #{message}"

    Rails.logger.info "Team sync completed for team: #{team.name} - #{results[:total]} members (#{results[:new_members]} new, #{results[:updated]} updated)"

    results
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Team not found: #{e.message}"
    team&.update!(sync_status: "failed")
    raise
  rescue StandardError => e
    Rails.logger.error "Team sync failed: #{e.message}"
    team&.update!(sync_status: "failed")
    raise
  end
end
