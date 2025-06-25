class AuditNote < ApplicationRecord
  belongs_to :audit_member
  belongs_to :user

  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
