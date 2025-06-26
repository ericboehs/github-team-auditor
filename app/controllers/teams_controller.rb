class TeamsController < ApplicationController
  before_action :set_team, only: [ :show, :edit, :update, :destroy, :sync, :find_issue_correlations ]

  def index
    @teams = Team.includes(:organization, :audit_sessions, :team_members).order(:name)
  end

  def show
    # Get current team members from team_members table with issue correlations preloaded
    @team_members = @team.team_members.includes(:issue_correlations).current.order(:github_login)
    @recent_audits_count = @team.audit_sessions.where(created_at: 30.days.ago..).count
    @total_members_count = @team_members.count
    @validated_members_count = 0 # Not applicable for team-level view
    @maintainer_members_count = @team_members.where(maintainer_role: true).count
    @last_synced_at = @team.last_synced_at
    @last_issue_correlation_at = @team.issue_correlation_completed_at

    respond_to do |format|
      format.html
      format.turbo_stream { head :ok }
    end
  end

  def new
    @team = Team.new
    @organizations = Organization.all

    # Default to Department of Veterans Affairs organization
    @default_organization = @organizations.find_by(github_login: "department-of-veterans-affairs")
    @team.organization = @default_organization if @default_organization
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to @team, notice: t("flash.teams.created")
    else
      @organizations = Organization.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @team.update(team_params)
      redirect_to @team, notice: t("flash.teams.updated")
    else
      @organizations = Organization.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @team.destroy
    redirect_to teams_url, notice: t("flash.teams.deleted")
  end

  def sync
    # Check if any jobs are already running
    if @team.any_jobs_running?
      alert_message = if @team.sync_running?
        t("flash.teams.sync_already_running")
      else
        t("flash.teams.cannot_sync_while_finding_issues")
      end

      respond_to do |format|
        format.html { redirect_to team_path(@team), alert: alert_message }
        format.turbo_stream { head :ok }
      end
      return
    end

    # Sync team data from GitHub in background
    @team.sync_from_github!

    respond_to do |format|
      format.html { redirect_to team_path(@team) }
      format.turbo_stream { head :ok }
    end
  end

  def find_issue_correlations
    # Check if any jobs are already running
    if @team.any_jobs_running?
      alert_message = if @team.issue_correlation_running?
        t("flash.teams.issue_correlation_already_running")
      else
        t("flash.teams.cannot_find_issues_while_syncing")
      end

      respond_to do |format|
        format.html { redirect_to team_path(@team), alert: alert_message }
        format.turbo_stream { head :ok }
      end
      return
    end

    # Validate that search terms are defined beyond the default
    if @team.search_terms.blank?
      respond_to do |format|
        format.html { redirect_to team_path(@team), alert: t("flash.teams.search_terms_required") }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_message", locals: { message: t("flash.teams.search_terms_required"), type: :alert })
        }
      end
      return
    end

    # Find issue correlations for team members in background using team's configuration
    IssueCorrelationFinderJob.perform_later(@team.id)

    respond_to do |format|
      format.html { redirect_to team_path(@team) }
      format.turbo_stream { head :ok }
    end
  end



  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :github_slug, :description, :organization_id, :search_terms, :exclusion_terms, :search_repository)
  end
end
