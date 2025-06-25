class TeamMember < ApplicationRecord
  include GithubUrlable

  belongs_to :team
  has_many :audit_members, dependent: :destroy
  has_many :audit_sessions, through: :audit_members
  has_many :issue_correlations, dependent: :destroy

  validates :github_login, uniqueness: { scope: :team_id }

  # Scope for current/active members
  scope :current, -> { where(active: true) }

  def open_issues
    issue_correlations.where(status: 'open')
  end

  def resolved_issues
    issue_correlations.where(status: 'resolved')
  end

  def has_open_issues?
    open_issues.exists?
  end

  def display_name
    name.presence || github_login
  end
end
