class IssueCorrelationFinderJob < ApplicationJob
  queue_as :default

  def perform(team_id, search_terms: nil, exclusion_terms: nil, repository: nil)
    @team = Team.find(team_id)
    @organization = @team.organization
    @api_client = @api_client || Github::ApiClient.new(@organization)

    # Use team's search configuration, with fallbacks to parameters or defaults
    @search_terms = search_terms || @team.effective_search_terms
    @exclusion_terms = (exclusion_terms || @team.effective_exclusion_terms).to_s.downcase
    @repository = repository || @team.effective_search_repository

    Rails.logger.info "Starting issue correlation finder for team #{@team.name} with search terms: #{@search_terms}"

    find_correlations_for_team
  end

  private

  def find_correlations_for_team
    @team.team_members.current.find_each do |team_member|
      find_correlations_for_member(team_member)
    rescue StandardError => e
      Rails.logger.error "Failed to find correlations for member #{team_member.github_login}: #{e.message}"
      # Continue with other members even if one fails
    end

    Rails.logger.info "Issue correlation finder completed for team #{@team.name}"
  end

  def find_correlations_for_member(team_member)
    Rails.logger.debug "Finding issue correlations for #{team_member.github_login}"

    # Build search query similar to legacy code: member login + search terms
    query = build_search_query(team_member.github_login)

    # Search for issues
    issues = @api_client.search_issues(query, repository: @repository)

    # Filter out excluded issues
    filtered_issues = filter_excluded_issues(issues)

    # Update correlations for this member
    update_correlations_for_member(team_member, filtered_issues)

    Rails.logger.debug "Found #{filtered_issues.count} issue correlations for #{team_member.github_login}"
  end

  def build_search_query(github_login)
    # Build query similar to legacy: search for member in both body and title, plus search terms in title
    "is:issue \"#{github_login}\" in:body \"#{github_login}\" in:title \"#{@search_terms}\""
  end

  def filter_excluded_issues(issues)
    return issues if @exclusion_terms.blank?

    issues.reject do |issue|
      title_lower = issue[:title].to_s.downcase
      title_lower.include?(@exclusion_terms)
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
end
