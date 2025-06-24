class AuditMember < ApplicationRecord
  include GithubUrlable

  belongs_to :audit_session
  has_many :audit_notes, dependent: :destroy
  has_many :issue_correlations, dependent: :destroy

  scope :validated, -> { where(access_validated: true) }
  scope :pending_validation, -> { where(access_validated: [ nil, false ]) }
  scope :marked_for_removal, -> { where(removed: true) }
  scope :maintainers, -> { where(maintainer_role: true) }
  scope :government_employees, -> { where(government_employee: true) }
  scope :active, -> { where(removed: [ nil, false ]) }
  scope :removed, -> { where(removed: true) }

  def validation_status
    case access_validated
    when true then "validated"
    else "pending"
    end
  end

  def removed?
    removed == true
  end

  def soft_delete!
    update!(removed: true)
  end

  def restore!
    update!(removed: false)
  end

  # Get issues from the corresponding team member
  def corresponding_team_member
    return nil unless audit_session.team

    audit_session.team.team_members.find_by(github_login: github_login)
  end

  def open_issues
    corresponding_team_member&.open_issues || IssueCorrelation.none
  end

  def resolved_issues
    corresponding_team_member&.resolved_issues || IssueCorrelation.none
  end

  def has_open_issues?
    corresponding_team_member&.has_open_issues? || false
  end
end
