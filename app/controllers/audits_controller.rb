class AuditsController < ApplicationController
  include Sortable

  before_action :set_audit_session, only: [ :show, :update, :destroy, :toggle_status ]

  def index
    @audit_sessions = AuditSession.includes(:organization, :team, :user)

    # Filter by team if team_id parameter is present
    if params[:team_id].present?
      @audit_sessions = @audit_sessions.where(team_id: params[:team_id])
      @filtered_team = Team.find(params[:team_id])
    end

    # Apply sorting
    @audit_sessions = apply_audit_sorting(@audit_sessions)

    @audit_sessions = @audit_sessions.limit(20)
    @organizations = Organization.all
  end

  def show
    @team_members =
      @audit_session
        .audit_members
        .includes(:audit_notes, :team_member)
        .joins(:team_member)

    # Apply sorting for team members
    @team_members = apply_team_member_sorting(@team_members)

    @progress = @audit_session.progress_percentage
    @compliance_status = @audit_session.compliance_ready?
  end

  def new
    @audit_session = AuditSession.new
    @organizations = Organization.all

    # If team_id is provided, pre-select the team and its organization
    if params[:team_id].present?
      @selected_team = Team.find(params[:team_id])
      @audit_session.team = @selected_team
      @audit_session.organization = @selected_team.organization
      @teams = @selected_team.organization.teams
    else
      # Auto-select the first organization if there's only one
      if @organizations.count == 1
        @audit_session.organization = @organizations.first
        @teams = @audit_session.organization.teams.recently_synced

        # Pre-select the most recently synced team
        most_recent_team = @teams.where.not(sync_completed_at: nil).first
        @audit_session.team = most_recent_team if most_recent_team
      else
        @teams = []
      end
    end
  end

  def create
    @audit_session = AuditSession.new(audit_session_params)
    @audit_session.user = Current.user
    @audit_session.status = "draft"
    @audit_session.started_at = Time.current

    if @audit_session.save
      @audit_session.sync_team_members!
      redirect_to audit_path(@audit_session), flash: { success: t("flash.audits.created") }
    else
      @organizations = Organization.all
      if @audit_session.organization
        @teams = @audit_session.organization.teams.recently_synced
      elsif @organizations.count == 1
        @teams = @organizations.first.teams.recently_synced
      else
        @teams = []
      end
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @audit_session.update(audit_session_params)
      redirect_to audit_path(@audit_session), flash: { success: t("flash.audits.updated") }
    else
      redirect_to audit_path(@audit_session), alert: @audit_session.errors.full_messages.join(", ")
    end
  end

  def destroy
    @audit_session.destroy
    redirect_to audits_path, flash: { success: t("flash.audits.deleted") }
  end

  def toggle_status
    # If a specific status is provided, use it; otherwise, use the toggle logic
    if params[:status].present? && %w[draft active completed].include?(params[:status])
      new_status = params[:status]
    else
      # Legacy toggle behavior
      new_status =
        case @audit_session.status
        when "active"
          "completed"
        when "completed"
          "active"
        when "draft"
          "active"
        else
          "active"
        end
    end

    if @audit_session.update(status: new_status, completed_at: new_status == "completed" ? Time.current : nil)
      notice_key = case new_status
      when "completed" then "marked_complete"
      when "active" then "marked_active"
      when "draft" then "marked_draft"
      else "marked_active"
      end
      redirect_to audit_path(@audit_session), flash: { success: t("flash.audits.#{notice_key}") }
    else
      redirect_to audit_path(@audit_session), alert: @audit_session.errors.full_messages.join(", ")
    end
  end

  private

  def set_audit_session
    @audit_session = AuditSession.find(params[:id])
  end

  def audit_session_params
    params.require(:audit_session).permit(:name, :organization_id, :team_id, :notes, :due_date)
  end

  def apply_audit_sorting(relation)
    case sort_column
    when "name"
      relation.order("audit_sessions.name #{sort_direction}")
    when "team"
      relation.joins(:team).order("teams.name #{sort_direction}")
    when "status"
      relation.order("audit_sessions.status #{sort_direction}")
    when "started"
      relation.order("audit_sessions.started_at #{sort_direction}")
    when "due_date"
      if sort_direction == "asc"
        relation.order("audit_sessions.due_date ASC NULLS LAST")
      else
        relation.order("audit_sessions.due_date DESC NULLS LAST")
      end
    else
      # Default sorting
      relation.recent
    end
  end

  def apply_team_member_sorting(relation)
    case sort_column
    when "member"
      relation.order(team_members: { github_login: sort_direction })
    when "role"
      direction = sort_direction == 'asc' ? :desc : :asc
      relation.order(team_members: { maintainer_role: direction })
    when "status"
      relation.order(audit_members: { access_validated: sort_direction })
    when "first_seen"
      # Sort by minimum issue_created_at from issue_correlations
      # For ascending: NULLs first, then oldest to newest
      # For descending: newest to oldest, then NULLs last
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"
      relation.joins("LEFT JOIN issue_correlations ic_first ON ic_first.team_member_id = team_members.id")
              .group("audit_members.id, team_members.id")
              .order(Arel.sql("MIN(ic_first.issue_created_at) #{sort_direction} #{nulls_position}"))
    when "last_seen"
      # Sort by maximum issue_updated_at from issue_correlations
      # For ascending: NULLs first, then oldest to newest
      # For descending: newest to oldest, then NULLs last
      nulls_position = sort_direction == "asc" ? "NULLS FIRST" : "NULLS LAST"
      relation.joins("LEFT JOIN issue_correlations ic_last ON ic_last.team_member_id = team_members.id")
              .group("audit_members.id, team_members.id")
              .order(Arel.sql("MAX(ic_last.issue_updated_at) #{sort_direction} #{nulls_position}"))
    else
      # Default sorting
      relation.order(team_members: { github_login: :asc })
    end
  end
end
