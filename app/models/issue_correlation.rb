class IssueCorrelation < ApplicationRecord
  belongs_to :team_member

  validates :github_issue_number, presence: true
  validates :github_issue_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :open, -> { where(status: "open") }
  scope :resolved, -> { where(status: "resolved") }

  def open?
    status == "open"
  end

  def resolved?
    status == "resolved"
  end
end
