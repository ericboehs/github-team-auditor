class AuditsController < ApplicationController
  include LoadsOrganizations

  before_action :set_audit_session, only: [ :show, :update, :destroy, :toggle_status ]
  before_action :load_organizations, only: [ :index, :new, :create ]

  def index
    @audit_sessions = AuditSession.includes(:organization, :team, :user)

    # Filter by team if team_id parameter is present
    if params[:team_id].present?
      @audit_sessions = @audit_sessions.where(team_id: params[:team_id])
      @filtered_team = Team.find(params[:team_id])
    end

    @audit_sessions = @audit_sessions.recent.limit(20)
  end

  def show
    @team_members = @audit_session.audit_members
                                .includes(:audit_notes)
                                .order(:github_login)
    @progress = @audit_session.progress_percentage
    @compliance_status = @audit_session.compliance_ready?
  end

  def new
    @audit_session = AuditSession.new

    # If team_id is provided, pre-select the team and its organization
    if params[:team_id].present?
      @selected_team = Team.find(params[:team_id])
      @audit_session.team = @selected_team
      @audit_session.organization = @selected_team.organization
      @teams = @selected_team.organization.teams
    else
      @teams = []
    end
  end

  def create
    @audit_session = AuditSession.new(audit_session_params)
    @audit_session.user = Current.user
    @audit_session.status = "draft"
    @audit_session.started_at = Time.current

    if @audit_session.save
      redirect_to audit_path(@audit_session), notice: t("flash.audits.created")
    else
      @teams = @audit_session.organization ? @audit_session.organization.teams : []
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @audit_session.update(audit_session_params)
      redirect_to audit_path(@audit_session), notice: t("flash.audits.updated")
    else
      redirect_to audit_path(@audit_session), alert: @audit_session.errors.full_messages.join(", ")
    end
  end

  def destroy
    @audit_session.destroy
    redirect_to audits_path, notice: t("flash.audits.deleted")
  end

  def toggle_status
    new_status = case @audit_session.status
    when "active"
                  "completed"
    when "completed"
                  "active"
    when "draft"
                  "active"
    else
                  "active"
    end

    if @audit_session.update(status: new_status, completed_at: new_status == "completed" ? Time.current : nil)
      notice_key = new_status == "completed" ? "marked_complete" : "marked_active"
      redirect_to audit_path(@audit_session), notice: t("flash.audits.#{notice_key}")
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
end
