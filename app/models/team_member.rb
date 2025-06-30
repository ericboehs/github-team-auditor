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

      # Extract from issue comments (with relative date calculation and maintainer check)
      dates.concat(extract_expiration_dates_from_comments_with_maintainer_check(issue))
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

  # Extract expiration dates from comments, including relative date calculations
  def extract_expiration_dates_from_comments(comments_text, reference_date = nil)
    return [] if comments_text.blank?

    dates = []

    # First try absolute date patterns
    dates.concat(extract_expiration_dates_from_text(comments_text))

    # If no absolute dates found, try relative patterns
    if dates.empty? && reference_date
      dates.concat(extract_relative_expiration_dates(comments_text, reference_date))
    end

    dates
  end

  # Extract expiration dates from comments, only considering comments by team maintainers
  def extract_expiration_dates_from_comments_with_maintainer_check(issue)
    return [] if issue.comments.blank? || issue.comment_authors.blank?

    # Get team maintainer usernames
    maintainer_usernames = team.team_members.where(maintainer_role: true).pluck(:github_login).map(&:downcase)

    # Split comments by separator and check each comment with its author
    comment_parts = issue.comments.split("\n\n---\n\n")
    comment_authors = issue.comment_authors || []

    # Get issue author to exclude from fallback
    issue_author = issue.issue_author&.downcase

    maintainer_dates = []
    fallback_dates = []

    comment_parts.each_with_index do |comment_text, index|
      # Skip if we don't have author info for this comment
      next if index >= comment_authors.length

      comment_author = comment_authors[index]&.downcase

      # Skip comments from the issue author for both maintainer and fallback checks
      next if comment_author == issue_author

      if maintainer_usernames.include?(comment_author)
        # Extract dates from current team maintainers
        maintainer_dates.concat(extract_expiration_dates_from_comments(comment_text, issue.issue_created_at))
      else
        # Extract dates from other commenters (historical maintainers, etc.)
        fallback_dates.concat(extract_expiration_dates_from_comments(comment_text, issue.issue_created_at))
      end
    end

    # Prefer maintainer dates when available, but fall back to historical dates
    # Always take the latest date to handle legitimate access extensions
    if maintainer_dates.any?
      # If maintainers have commented with dates, prioritize those but also consider fallback
      # in case a historical maintainer granted a longer extension
      all_dates = (maintainer_dates + fallback_dates).uniq
      # Return the latest date, giving priority to maintainer dates in case of ties
      latest_maintainer = maintainer_dates.max
      latest_fallback = fallback_dates.max
      
      if latest_fallback && latest_maintainer && latest_fallback > latest_maintainer
        # Historical maintainer granted longer access - use that
        [ latest_fallback ]
      else
        # Use maintainer date
        [ latest_maintainer ]
      end
    elsif fallback_dates.any?
      # No current maintainer dates, use fallback (historical maintainers)
      [ fallback_dates.max ]
    else
      []
    end
  end

  # Extract relative expiration dates from text (e.g., "approved for 6 months")
  def extract_relative_expiration_dates(text, reference_date)
    return [] if text.blank? || reference_date.blank?

    dates = []
    reference_date = reference_date.to_date if reference_date.respond_to?(:to_date)

    # Pattern 1: "approved for X months", "granted you X months access", "given X months approval"
    text.scan(/(?:approved|granted|given)(?:\s+you)?(?:\s+for)?\s+(\d+)\s+months?\s+(?:of\s+)?(?:access|approval)/i) do |match|
      months = match[0].to_i
      if months > 0 && months <= 24 # Reasonable range
        expiration_date = reference_date + months.months
        dates << expiration_date unless dates.include?(expiration_date)
      end
    end

    # Pattern 2: "access for X months", "valid for X months" (but not if it was caught by pattern 1)
    unless dates.any?
      text.scan(/(?:access|valid)\s+for\s+(\d+)\s+months?/i) do |match|
        months = match[0].to_i
        if months > 0 && months <= 24
          expiration_date = reference_date + months.months
          dates << expiration_date unless dates.include?(expiration_date)
        end
      end
    end

    # Pattern 3: "X month approval", "X-month access" (only if no other patterns matched)
    unless dates.any?
      text.scan(/(\d+)[-\s]months?\s+(?:approval|access|extension)/i) do |match|
        months = match[0].to_i
        if months > 0 && months <= 24
          expiration_date = reference_date + months.months
          dates << expiration_date unless dates.include?(expiration_date)
        end
      end
    end

    dates.compact.uniq
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
