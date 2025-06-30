class IssueCorrelationService
  attr_reader :team, :graphql_client, :search_terms, :exclusion_terms, :repository

  def initialize(team, search_terms:, exclusion_terms:, repository:)
    @team = team
    @graphql_client = Github::GraphqlClient.new(team.organization)
    @search_terms = search_terms
    @exclusion_terms = exclusion_terms.to_s.downcase
    @repository = repository
  end

  def find_correlations_for_team
    Rails.logger.info "Starting batch GraphQL issue correlation for team #{team.name}"
    Rails.logger.info "Search config: terms='#{search_terms}', exclusion='#{exclusion_terms}', repo='#{repository}'"

    team_members = team.team_members.includes(:issue_correlations).current.order(:github_login)

    # Use GraphQL batch search for much better performance (6-10x faster)
    batch_results = graphql_client.batch_search_issues_for_members(
      team_members,
      search_terms: search_terms,
      repository: repository,
      exclusion_terms: exclusion_terms
    )

    Rails.logger.info "GraphQL batch search completed. Processing #{team_members.count} members"

    # Update correlations for each member
    team_members.each do |team_member|
      issues = batch_results[team_member.github_login] || []
      update_correlations_for_member(team_member, issues)
    end

    Rails.logger.info "Issue correlation processing completed for team #{team.name}"
  end

  private

  def update_correlations_for_member(team_member, issues)
    current_time = Time.current

    Rails.logger.debug "Updating #{issues.count} issue correlations for #{team_member.github_login}"

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
        issue_author: issue.dig(:user, :github_login),
        comments: issue[:comments],
        comment_authors: issue[:comment_authors]&.to_json,
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

    # Fetch comments for issue correlations that don't have them yet
    fetch_comments_for_issues(team_member)

    # Extract and update access expiration date from issue descriptions and comments
    begin
      team_member.extract_and_update_access_expires_at!
      Rails.logger.debug "Updated access expiration for #{team_member.github_login}: #{team_member.access_expires_at}"
    rescue StandardError => e
      Rails.logger.error "Failed to extract access expiration for #{team_member.github_login}: #{e.message}"
      # Don't raise the error - expiration extraction is not critical to the main workflow
    end

    # Broadcast updated issues for this member via Turbo Stream
    broadcast_member_issues_update(team_member)
  end

  def truncate_description(body)
    return nil if body.blank?

    # Truncate to reasonable length for database storage
    body.to_s.truncate(1000)
  end

  def fetch_comments_for_issues(team_member)
    # Comments are now included in the GraphQL batch response, so this method is only needed
    # as a fallback for issues that might have missing comment data
    issues_needing_comments = team_member.issue_correlations.where(comments: [ nil, "" ])

    return if issues_needing_comments.empty?

    Rails.logger.debug "Fetching missing comments for #{issues_needing_comments.count} issues for #{team_member.github_login} (GraphQL fallback)"

    github_client = Github::ApiClient.new(team_member.team.organization)

    issues_needing_comments.find_each do |issue_correlation|
      begin
        # Extract repo name from issue URL (e.g., "va.gov-team" from GitHub URL)
        repo_name = extract_repo_name_from_url(issue_correlation.github_issue_url)
        next unless repo_name

        # Fetch comments for this issue using REST API as fallback
        comments = github_client.fetch_issue_comments(repo_name, issue_correlation.github_issue_number)

        # Combine all comment bodies into a single text field
        comments_text = comments.map { |comment| comment[:body] }.join("\n\n---\n\n")

        # Extract comment authors
        comment_authors = comments.map { |comment| comment[:author] }

        # Update the issue correlation with comments and authors
        issue_correlation.update!(comments: comments_text, comment_authors: comment_authors)

        Rails.logger.debug "Fetched #{comments.count} comments for issue ##{issue_correlation.github_issue_number} via REST fallback"

      rescue StandardError => e
        Rails.logger.error "Failed to fetch comments for issue ##{issue_correlation.github_issue_number}: #{e.message}"
        # Continue with other issues even if one fails
        next
      end
    end
  end

  def extract_repo_name_from_url(github_url)
    # Extract repo name from URLs like:
    # https://github.com/department-of-veterans-affairs/va.gov-team/issues/12345
    match = github_url.match(%r{github\.com/[^/]+/([^/]+)/issues/})
    match&.[](1)
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
