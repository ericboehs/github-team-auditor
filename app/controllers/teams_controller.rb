class TeamsController < ApplicationController
  before_action :set_team, only: [ :show, :edit, :update, :destroy, :sync, :find_issue_correlations, :poll ]

  def index
    @teams = Team.includes(:organization, :audit_sessions).order(:name)
  end

  def show
    # Get current team members from team_members table
    @team_members = @team.team_members.current.order(:github_login)
    @recent_audits_count = @team.audit_sessions.where(created_at: 30.days.ago..).count
    @total_members_count = @team_members.count
    @validated_members_count = 0 # Not applicable for team-level view
    @maintainer_members_count = @team_members.where(maintainer_role: true).count
    @last_synced_at = @team.last_synced_at
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
    # Sync team data from GitHub in background
    @team.sync_from_github!

    redirect_to team_path(@team), notice: t("flash.teams.sync_started")
  end

  def find_issue_correlations
    # Find issue correlations for team members in background using team's configuration
    IssueCorrelationFinderJob.perform_later(@team.id)

    redirect_to team_path(@team), notice: t("flash.teams.issue_correlation_started")
  end

  def poll
    # Get updated team data for polling
    @team_members = @team.team_members.current.order(:github_login)
    @total_members_count = @team_members.count
    @validated_members_count = 0 # Not applicable for team-level view
    @maintainer_members_count = @team_members.where(maintainer_role: true).count
    @last_synced_at = @team.last_synced_at

    respond_to do |format|
      format.turbo_stream
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
