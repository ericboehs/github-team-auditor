class AuditSession < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :team
  has_many :audit_members, dependent: :destroy

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft active completed archived] }

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :recent, -> { order(created_at: :desc) }

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def progress_percentage
    active_members = audit_members.active
    return 0 if active_members.count.zero?
    (active_members.where.not(access_validated: nil).count.to_f / active_members.count * 100).round(1)
  end

  def maintainer_members
    audit_members.active.maintainers
  end

  def government_employee_maintainers
    maintainer_members.government_employees
  end

  def compliance_ready?
    maintainer_members.count >= 2 && government_employee_maintainers.any?
  end

  def sync_team_members!
    team.team_members.current.find_each do |team_member|
      audit_members.find_or_create_by!(team_member: team_member) do |audit_member|
        audit_member.access_validated = nil
        audit_member.removed = false
      end
    end
  end
end
