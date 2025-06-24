class TeamMember < ApplicationRecord
  include GithubUrlable

  belongs_to :team
  belongs_to :audit_session, optional: true

  validates :github_login, uniqueness: { scope: :team_id }

  # Scope for current/active members
  scope :current, -> { where(active: true) }

  # Issues that are relevant for audits - now found through audit members
  def open_issues
    IssueCorrelation.joins(:audit_member)
                    .where(audit_members: { github_login: github_login })
  end

  def resolved_issues
    IssueCorrelation.joins(:audit_member)
                    .where(audit_members: { github_login: github_login })
                    .where("1 = 0") # No resolved issues since we don't track status
  end

  def has_open_issues?
    open_issues.exists?
  end
end
