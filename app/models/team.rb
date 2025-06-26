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
  JOB_TYPES = %w[sync issue_correlation].freeze

  def sync_running?
    job_running?(:sync)
  end

  def issue_correlation_running?
    job_running?(:issue_correlation)
  end

  def any_jobs_running?
    JOB_TYPES.any? { |job_type| job_running?(job_type) }
  end

  def start_sync_job!
    start_job!(:sync)
  end

  def complete_sync_job!
    complete_job!(:sync, completion_field: :last_synced_at)
  end

  def start_issue_correlation_job!
    start_job!(:issue_correlation)
  end

  def complete_issue_correlation_job!
    complete_job!(:issue_correlation, completion_field: :issue_correlation_completed_at)
  end

  def current_job_status
    if sync_running? && issue_correlation_running?
      # When both are running, prioritize the more specific issue correlation status
      issue_correlation_status
    elsif sync_running?
      sync_status == "running" ? I18n.t("models.team.status.syncing") : sync_status
    elsif issue_correlation_running?
      issue_correlation_status == "running" ? I18n.t("models.team.status.finding_issues") : issue_correlation_status
    end
  end

  private

  def job_running?(job_type)
    send("#{job_type}_status").present?
  end

  def start_job!(job_type)
    update!(
      "#{job_type}_status" => "running",
      "#{job_type}_started_at" => Time.current
    )
  end

  def complete_job!(job_type, completion_field: nil)
    attributes = {
      "#{job_type}_status" => nil,
      "#{job_type}_started_at" => nil
    }

    if completion_field
      attributes[completion_field.to_s] = Time.current
    end

    update!(attributes)
  end
end
