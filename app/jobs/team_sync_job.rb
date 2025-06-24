class TeamSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on Github::ApiClient::ConfigurationError

  def perform(team_id)
    team = Team.find(team_id)

    Rails.logger.info "Starting team sync for team: #{team.name}"

    # Sync team members to team_members table
    sync_service = Github::TeamSyncService.new(team)
    results = sync_service.sync_team_members

    # Update team's last synced timestamp
    team.update!(last_synced_at: Time.current)

    Rails.logger.info "Team sync completed for team: #{team.name} - #{results[:total]} members (#{results[:new_members]} new, #{results[:updated]} updated)"

    results
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Team not found: #{e.message}"
    raise
  rescue StandardError => e
    Rails.logger.error "Team sync failed: #{e.message}"
    raise
  end
end
