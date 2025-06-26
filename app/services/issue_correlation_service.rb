class IssueCorrelationService
  attr_reader :team, :api_client, :search_terms, :exclusion_terms, :repository

  def initialize(team, api_client:, search_terms:, exclusion_terms:, repository:)
    @team = team
    @api_client = api_client
    @search_terms = search_terms
    @exclusion_terms = exclusion_terms.to_s.downcase
    @repository = repository
  end

  def find_correlations_for_member(team_member)
    Rails.logger.debug "Finding issue correlations for #{team_member.github_login}"

    # Build search query similar to legacy code: member login + search terms
    query = build_search_query(team_member.github_login)

    # Search for issues
    issues = api_client.search_issues(query, repository: repository)

    # Filter out excluded issues
    filtered_issues = filter_excluded_issues(issues)

    # Update correlations for this member
    update_correlations_for_member(team_member, filtered_issues)

    Rails.logger.debug "Found #{filtered_issues.count} issue correlations for #{team_member.github_login}"
    filtered_issues
  end

  private

  def build_search_query(github_login)
    # Sanitize inputs to prevent search query injection
    safe_login = sanitize_search_term(github_login)
    safe_search_terms = sanitize_search_term(search_terms)

    # Build query similar to legacy: search for member in both body and title, plus search terms in title
    "is:issue \"#{safe_login}\" in:body \"#{safe_login}\" in:title \"#{safe_search_terms}\""
  end

  def sanitize_search_term(term)
    return "" if term.blank?

    # Remove potentially dangerous characters that could break GitHub search syntax
    # Keep alphanumeric, spaces, hyphens, underscores, and dots
    sanitized = term.to_s.gsub(/[^\w\s\-\.]/, "")

    # Limit length to prevent excessively long queries
    sanitized.truncate(100)
  end

  def filter_excluded_issues(issues)
    return issues if exclusion_terms.blank?

    issues.reject do |issue|
      title_lower = issue[:title].to_s.downcase
      title_lower.include?(exclusion_terms)
    end
  end

  def update_correlations_for_member(team_member, issues)
    current_time = Time.current

    # Get existing correlations to identify what to update vs create
    existing_correlations = team_member.issue_correlations.index_by(&:github_issue_number)

    # Prepare data for upsert
    upsert_data = issues.map do |issue|
      existing = existing_correlations[issue[:github_issue_number]]

      {
        team_member_id: team_member.id,
        github_issue_number: issue[:github_issue_number],
        github_issue_url: issue[:github_issue_url],
        title: issue[:title],
        description: truncate_description(issue[:body]),
        status: map_issue_status(issue[:state]),
        issue_created_at: issue[:created_at],
        issue_updated_at: issue[:updated_at],
        created_at: existing&.created_at || current_time,
        updated_at: current_time
      }
    end

    # Wrap all correlation updates in a transaction for consistency
    ApplicationRecord.transaction do
      if upsert_data.any?
        # Use upsert to handle both new and existing correlations
        IssueCorrelation.upsert_all(
          upsert_data,
          unique_by: [ :team_member_id, :github_issue_number ]
        )
      end

      # Remove correlations for issues that no longer match the search
      current_issue_numbers = issues.map { |i| i[:github_issue_number] }
      if current_issue_numbers.any?
        team_member.issue_correlations
          .where.not(github_issue_number: current_issue_numbers)
          .destroy_all
      else
        # If no issues found, remove all existing correlations for this member
        team_member.issue_correlations.destroy_all
      end
    end

    # Reload the team member to get fresh issue correlations
    team_member.reload

    # Broadcast updated issues for this member via Turbo Stream
    broadcast_member_issues_update(team_member)
  end

  def truncate_description(body)
    return nil if body.blank?

    # Truncate to reasonable length for database storage
    body.to_s.truncate(1000)
  end

  def map_issue_status(github_state)
    case github_state.to_s.downcase
    when "open"
      "open"
    when "closed"
      "resolved"
    else
      "open" # Default to open for unknown states
    end
  end

  def broadcast_member_issues_update(team_member)
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{team.id}",
      target: "member-issues-#{team_member.id}",
      partial: "teams/member_issues",
      locals: { member: team_member }
    )
  end
end
