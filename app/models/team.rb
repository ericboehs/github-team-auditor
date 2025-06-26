class Team < ApplicationRecord
  belongs_to :organization
  has_many :audit_sessions, dependent: :destroy
  has_many :team_members, dependent: :destroy

  validates :name, presence: true
  validates :github_slug, presence: true, uniqueness: { scope: :organization_id }

  # Default search configuration
  def effective_search_terms
    search_terms.presence || "access"
  end

  def effective_exclusion_terms
    exclusion_terms.presence || ""
  end

  def effective_search_repository
    search_repository.presence || "#{organization.github_login}/va.gov-team"
  end

  scope :recently_synced, -> { order(last_synced_at: :desc) }

  def github_url
    "https://github.com/orgs/#{organization.github_login}/teams/#{github_slug}"
  end

  def sync_from_github!
    TeamSyncJob.perform_later(id)
  end

  def sync_from_github_now!
    TeamSyncJob.perform_now(id)
  end

  def active_audit_sessions
    audit_sessions.where(status: [ "draft", "active" ])
  end

  def name_with_slug
    "#{name} (#{github_slug})"
  end

  # Job status management
  def sync_running?
    sync_status.present?
  end

  def issue_correlation_running?
    issue_correlation_status.present?
  end

  def any_jobs_running?
    sync_running? || issue_correlation_running?
  end

  def start_sync_job!
    update!(sync_status: "running", sync_started_at: Time.current)
  end

  def complete_sync_job!
    update!(
      sync_status: nil,
      sync_started_at: nil,
      last_synced_at: Time.current
    )
  end

  def start_issue_correlation_job!
    update!(issue_correlation_status: "running", issue_correlation_started_at: Time.current)
  end

  def complete_issue_correlation_job!
    update!(
      issue_correlation_status: nil,
      issue_correlation_started_at: nil,
      issue_correlation_completed_at: Time.current
    )
  end

  def current_job_status
    if sync_running? && issue_correlation_running?
      # When both are running, prioritize the more specific issue correlation status
      issue_correlation_status
    elsif sync_running?
      sync_status == "running" ? "Syncing team members from GitHub..." : sync_status
    elsif issue_correlation_running?
      issue_correlation_status == "running" ? "Finding GitHub issues for team members..." : issue_correlation_status
    end
  end
end
