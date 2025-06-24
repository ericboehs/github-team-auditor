class IssueCorrelation < ApplicationRecord
  belongs_to :audit_member

  validates :github_issue_number, presence: true
  validates :github_issue_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def open?
    true # All issues are considered open by default since we don't track status
  end

  def resolved?
    false # No resolution tracking without status field
  end
end
