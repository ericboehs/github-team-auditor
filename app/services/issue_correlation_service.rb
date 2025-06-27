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
