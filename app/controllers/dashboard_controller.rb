class DashboardController < ApplicationController
  def index
    @total_teams = Team.count
    @total_organizations = Organization.count
    @total_current_members = TeamMember.current.count
    @recent_audits = AuditSession.includes(:team).order(created_at: :desc).limit(5)
    @teams_needing_sync = Team.where("sync_completed_at < ? OR sync_completed_at IS NULL", 7.days.ago).limit(5)
  end
end
