class IssueCorrelationFinderJob < ApplicationJob
  queue_as :default

  # Retry on transient errors but not on permanent failures  
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    # Don't retry on configuration errors
    raise error if error.is_a?(Github::ApiClient::ConfigurationError)
    
    # Log retry attempt
    Rails.logger.warn "Issue correlation job retrying due to: #{error.message}"
  end

  # Don't retry on configuration errors
  discard_on Github::ApiClient::ConfigurationError

  def perform(team_id, search_terms: nil, exclusion_terms: nil, repository: nil)
    @team = Team.find(team_id)
    @organization = @team.organization

    # Create API client with rate limit callback for countdown display
    rate_limit_callback = lambda do |remaining_seconds|
      update_rate_limit_status(remaining_seconds)
    end
    @api_client = @api_client || Github::ApiClient.new(@organization, rate_limit_callback: rate_limit_callback)

    # Use team's search configuration, with fallbacks to parameters or defaults
    @search_terms = search_terms || @team.effective_search_terms
    @exclusion_terms = (exclusion_terms || @team.effective_exclusion_terms).to_s.downcase
    @repository = repository || @team.effective_search_repository

    Rails.logger.info "Starting issue correlation finder for team #{@team.name} with search terms: #{@search_terms}"
    @team.start_issue_correlation_job!

    # Broadcast correlation started to team show page
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "status-banner-container",
      partial: "shared/status_banner",
      locals: { message: "Finding GitHub issues for team members...", type: :info, spinner: true }
    )

    # Broadcast syncing state to team index page
    @team.reload # Get fresh issue_correlation_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "teams_index",
      target: "team-card-#{@team.id}",
      partial: "teams/team_card",
      locals: { team: @team }
    )

    find_correlations_for_team

    # Count the results for a better message
    total_issues = @team.team_members.joins(:issue_correlations).count
    message = "Issue correlation completed successfully! Found #{total_issues} issues across team members."

    # Complete the job first
    @team.complete_issue_correlation_job!

    # Broadcast completion message via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "flash-messages",
      partial: "shared/turbo_flash_message",
      locals: { message: message, type: :success }
    )

    # Clear status banner
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "status-banner-container",
      html: ""
    )

    # Update actions dropdown to re-enable buttons
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{@team.id}",
      target: "team-actions-dropdown",
      partial: "teams/team_actions_dropdown",
      locals: { team: @team }
    )

    # Update team card on index page to remove syncing badge
    @team.reload # Ensure fresh data
    Turbo::StreamsChannel.broadcast_replace_to(
      "teams_index",
      target: "team-card-#{@team.id}",
      partial: "teams/team_card",
      locals: { team: @team }
    )

    Rails.logger.info "Broadcasted correlation completion message for team #{@team.id}: #{message}"
    Rails.logger.info "Issue correlation finder completed for team #{@team.name}"
  rescue StandardError => e
    Rails.logger.error "Issue correlation finder failed for team #{@team&.name}: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace&.first(5)&.join(', ')}"

    # Mark team as failed and broadcast error message
    @team&.update!(issue_correlation_status: "failed")

    # Broadcast error message to user
    broadcast_error_message(e)

    # Clear status banner
    broadcast_clear_status_banner

    # Update actions dropdown to re-enable buttons
    broadcast_dropdown_update

    raise
  end

  private

  def find_correlations_for_team
    members = @team.team_members.includes(:issue_correlations).current.order(:github_login)
    total_members = members.count
    @current_index = 0

    members.each do |team_member|
      @current_index += 1
      @current_member = team_member.github_login
      @total_members = total_members

      # Update status with current progress
      update_progress_status

      find_correlations_for_member(team_member)
    rescue StandardError => e
      Rails.logger.error "Failed to find correlations for member #{team_member.github_login}: #{e.message}"
      # Continue with other members even if one fails
    end
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
    # Sanitize inputs to prevent search query injection
    safe_login = sanitize_search_term(github_login)
    safe_search_terms = sanitize_search_term(@search_terms)

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

    # Reload the team member to get fresh issue correlations for broadcast
    team_member.reload

    # Broadcast updated issues for this member via Turbo Stream
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{@team.id}",
      target: "member-issues-#{team_member.id}",
      partial: "teams/member_issues",
      locals: { member: team_member }
    )
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

  def update_progress_status
    progress_message = "Finding issues for #{@current_member} (#{@current_index}/#{@total_members})..."

    # Broadcast only the message text update (keeps spinner spinning smoothly)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "status-message",
      html: progress_message
    )
  end

  def update_rate_limit_status(remaining_seconds)
    if remaining_seconds > 0
      # Combine progress and rate limit information
      combined_message = "Finding issues for #{@current_member} (#{@current_index}/#{@total_members}). Waiting #{remaining_seconds} seconds for GitHub's rate limit..."

      # Broadcast only the message text update (keeps spinner spinning smoothly)
      Turbo::StreamsChannel.broadcast_update_to(
        "team_#{@team.id}",
        target: "status-message",
        html: combined_message
      )
    else
      # Resume with progress information
      update_progress_status
    end
  end

  def broadcast_error_message(error)
    return unless @team

    # Create user-friendly error message
    friendly_message = case error
    when Github::ApiClient::ConfigurationError
      "GitHub configuration error. Please check your organization and team settings."
    when Octokit::Unauthorized
      "GitHub authentication failed. Please check your GitHub token configuration."
    when Octokit::TooManyRequests
      "GitHub API rate limit exceeded. The issue correlation search will automatically retry."
    when Octokit::NetworkError, Net::TimeoutError, Errno::ECONNREFUSED
      "Network connection error occurred. The issue correlation search will automatically retry."
    else
      "An unexpected error occurred during issue correlation search. Please try again."
    end

    # Broadcast error message via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "flash-messages",
      partial: "shared/turbo_flash_message",
      locals: { message: friendly_message, type: :alert }
    )
  end

  def broadcast_clear_status_banner
    return unless @team

    # Clear the status banner
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{@team.id}",
      target: "status-banner-container",
      html: ""
    )
  end

  def broadcast_dropdown_update
    return unless @team

    # Update actions dropdown to re-enable buttons
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{@team.id}",
      target: "team-actions-dropdown",
      partial: "teams/team_actions_dropdown",
      locals: { team: @team }
    )
  end
end
