class Organization < ApplicationRecord
  has_many :teams, dependent: :destroy
  has_many :audit_sessions, dependent: :destroy

  validates :name, presence: true
  validates :github_login, presence: true, uniqueness: true

  encrypts :api_token

  serialize :settings, coder: JSON

  def github_url
    "https://github.com/#{github_login}"
  end
end
