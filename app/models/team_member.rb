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
    issue_correlations.where(status: "open")
  end

  def resolved_issues
    issue_correlations.where(status: "resolved")
  end

  def has_open_issues?
    open_issues.exists?
  end

  def display_name
    name.presence || github_login
  end

  def first_seen_at
    issue_correlations.minimum(:issue_created_at)
  end

  def last_seen_at
    issue_correlations.maximum(:issue_updated_at)
  end

  # Extract and store the latest expiration date from issue descriptions
  def extract_and_update_access_expires_at!
    extracted_date = extract_latest_expiration_date
    update!(access_expires_at: extracted_date) if extracted_date != access_expires_at
    extracted_date
  end

  # Check if access is expiring soon (within 30 days)
  def access_expiring_soon?
    return false unless access_expires_at
    access_expires_at <= 30.days.from_now
  end

  # Check if access has already expired
  def access_expired?
    return false unless access_expires_at
    access_expires_at <= Time.current
  end

  private

  # Extract the latest expiration date from all issue descriptions and comments
  def extract_latest_expiration_date
    dates = []
    
    issue_correlations.each do |issue|
      # Extract from issue description
      dates.concat(extract_expiration_dates_from_text(issue.description.to_s))
      
      # Extract from issue comments
      dates.concat(extract_expiration_dates_from_text(issue.comments.to_s))
    end
    
    dates.compact.max
  end

  # Extract expiration dates from text using various patterns
  def extract_expiration_dates_from_text(text)
    return [] if text.blank?

    dates = []

    # Pattern 1: "expiring 09/18/25", "expires 12/31/2024", "expired 01/15/25"
    text.scan(/(?:expir(?:ing|es|ed)|valid|access)\s+(?:on|until|through)?\s*(\d{1,2}\/\d{1,2}\/(?:\d{2}|\d{4}))/i) do |match|
      dates << parse_date_string(match[0])
    end

    # Pattern 2: "access until 03/15/25", "valid until January 15, 2025"
    text.scan(/(?:access|valid)\s+(?:until|through)\s+(\d{1,2}\/\d{1,2}\/(?:\d{2}|\d{4}))/i) do |match|
      dates << parse_date_string(match[0])
    end

    # Pattern 3: "valid until January 15, 2025", "expires December 31, 2024"
    text.scan(/(?:expir(?:ing|es|ed)|valid|access)\s+(?:on|until|through)?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})/i) do |match|
      dates << parse_date_string(match[0])
    end

    # Pattern 4: "until 2025-01-15", "expires 2024-12-31"
    text.scan(/(?:expir(?:ing|es|ed)|valid|access|until)\s+(?:on|until|through)?\s*(\d{4}-\d{1,2}-\d{1,2})/i) do |match|
      dates << parse_date_string(match[0])
    end

    # Pattern 5: Simple date formats at end of sentences
    text.scan(/(?:^|\s)(\d{1,2}\/\d{1,2}\/(?:\d{2}|\d{4}))(?:\s|$|\.)/i) do |match|
      # Only include dates that appear in an expiration context
      match_pos = text.index(match[0])
      if match_pos
        context_start = [ match_pos - 50, 0 ].max
        context_end = [ match_pos + match[0].length + 50, text.length ].min
        context = text[context_start..context_end]
        if context.match?(/expir|valid|access|until|through/i)
          dates << parse_date_string(match[0])
        end
      end
    end

    dates.compact
  end

  # Parse various date string formats into Date objects
  def parse_date_string(date_str)
    return nil if date_str.blank?

    # Try different parsing approaches
    begin
      # Handle MM/DD/YY and MM/DD/YYYY formats
      if date_str.match?(/^\d{1,2}\/\d{1,2}\/\d{2,4}$/)
        parts = date_str.split("/")
        month, day, year = parts[0].to_i, parts[1].to_i, parts[2].to_i

        # Convert 2-digit years to 4-digit (assume 20xx for years < 50, 19xx for >= 50)
        if year < 100
          year = year < 50 ? 2000 + year : 1900 + year
        end

        return Date.new(year, month, day)
      end

      # Handle YYYY-MM-DD format
      if date_str.match?(/^\d{4}-\d{1,2}-\d{1,2}$/)
        return Date.parse(date_str)
      end

      # Handle "Month DD, YYYY" format
      if date_str.match?(/^[A-Za-z]+\s+\d{1,2},?\s+\d{4}$/)
        return Date.parse(date_str)
      end

      # Fallback to Ruby's Date.parse
      Date.parse(date_str)
    rescue ArgumentError, Date::Error
      # Return nil if parsing fails
      nil
    end
  end
end
