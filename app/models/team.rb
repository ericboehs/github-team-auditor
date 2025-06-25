class Team < ApplicationRecord
  belongs_to :organization
  has_many :audit_sessions, dependent: :destroy
  has_many :team_members, dependent: :destroy

  validates :name, presence: true
  validates :github_slug, presence: true, uniqueness: { scope: :organization_id }

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
end
