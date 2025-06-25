class AuditMember < ApplicationRecord
  belongs_to :audit_session
  belongs_to :team_member
  has_many :audit_notes, dependent: :destroy

  # Delegate member data to team_member
  delegate :github_login, :name, :avatar_url, :maintainer_role, :government_employee, 
           :last_seen_at, :first_seen_at, :github_url, :display_name, to: :team_member

  scope :validated, -> { where(access_validated: true) }
  scope :pending_validation, -> { where(access_validated: [ nil, false ]) }
  scope :marked_for_removal, -> { where(removed: true) }
  scope :maintainers, -> { joins(:team_member).where(team_members: { maintainer_role: true }) }
  scope :government_employees, -> { joins(:team_member).where(team_members: { government_employee: true }) }
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

  def open_issues
    team_member.open_issues
  end

  def resolved_issues
    team_member.resolved_issues
  end

  def has_open_issues?
    team_member.has_open_issues?
  end
end
