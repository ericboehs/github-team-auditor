# frozen_string_literal: true

module GithubUrlable
  extend ActiveSupport::Concern

  included do
    validates :github_login,
              presence: true,
              format: {
                with: /\A[a-zA-Z0-9\-_]+\z/,
                message: "can only contain letters, numbers, dashes, and underscores"
              }
  end

  def github_url
    return nil if github_login.blank?

    sanitized_login = github_login.gsub(/[^a-zA-Z0-9\-_]/, "")
    "https://github.com/#{sanitized_login}"
  end

  def display_name
    name.present? ? name : github_login
  end
end
