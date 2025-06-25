module Github
  class ApiClient
    include ActiveSupport::Configurable

    class ConfigurationError < StandardError; end

    config_accessor :default_rate_limit_delay, default: ApiConfiguration::DEFAULT_RATE_LIMIT_DELAY
    config_accessor :max_retries, default: ApiConfiguration::MAX_RETRIES

    def initialize(organization)
      @organization = organization
      token = ENV["GHTA_GITHUB_TOKEN"]
      raise ConfigurationError, "GHTA_GITHUB_TOKEN environment variable is required" if token.blank?
      @client = Octokit::Client.new(access_token: token)
      configure_client
    end

    def fetch_team_members(team_slug)
      with_rate_limiting do
        fetch_team_members_with_graphql(team_slug)
      end
    rescue Octokit::NotFound
      []
    end

    def fetch_team_members_with_graphql(team_slug)
      query = <<~GRAPHQL
        query($org: String!, $slug: String!, $after: String) {
          organization(login: $org) {
            team(slug: $slug) {
              members(first: #{ApiConfiguration::GRAPHQL_PAGE_SIZE}, after: $after) {
                edges {
                  role
                  node {
                    id
                    login
                    name
                    avatarUrl
                    databaseId
                  }
                }
                pageInfo {
                  hasNextPage
                  endCursor
                }
              }
            }
          }
        }
      GRAPHQL

      all_members = []
      after_cursor = nil

      loop do
        variables = {
          org: @organization.github_login,
          slug: team_slug,
          after: after_cursor
        }

        response = @client.post("/graphql", { query: query, variables: variables }.to_json)
        team_data = response.dig(:data, :organization, :team)

        break unless team_data&.dig(:members)

        members = team_data[:members]
        all_members.concat(members[:edges])

        break unless members.dig(:pageInfo, :hasNextPage)
        after_cursor = members.dig(:pageInfo, :endCursor)
      end

      # Transform GraphQL response to our format
      all_members.map do |edge|
        member = edge[:node]
        {
          github_login: member[:login],
          name: member[:name],
          avatar_url: member[:avatarUrl],
          maintainer_role: edge[:role] == "MAINTAINER"
        }
      end
    end

    def fetch_team_by_slug(team_slug)
      with_rate_limiting do
        team = @client.team_by_name(@organization.github_login, team_slug)
        normalize_team_data(team)
      end
    rescue Octokit::NotFound
      nil
    end

    def search_issues(query, repository: nil)
      repo = repository || "#{@organization.github_login}/va.gov-team"
      search_query = "repo:#{repo} #{query}"
      Rails.logger.debug "Searching issues with query: #{search_query}"

      with_rate_limiting do
        results = @client.search_issues(search_query)
        normalized_results = results.items.map { |issue| normalize_issue_data(issue) }
        Rails.logger.debug "Found #{normalized_results.length} issues"
        normalized_results
      end
    end

    def user_details(username)
      with_rate_limiting do
        user = @client.user(username)
        normalize_user_data(user)
      end
    rescue Octokit::NotFound
      nil
    end

    private

    def configure_client
      @client.auto_paginate = true
      @client.per_page = ApiConfiguration::DEFAULT_PAGE_SIZE
    end

    def team_id_for_slug(team_slug)
      team = fetch_team_by_slug(team_slug)
      team&.dig(:id) || raise(Octokit::NotFound.new("Team not found: #{team_slug}"))
    end

    def with_rate_limiting(&block)
      retries = 0
      begin
        check_rate_limit
        yield
      rescue Octokit::TooManyRequests => e
        if retries < config.max_retries
          retries += 1
          reset_time = e.response_headers["x-ratelimit-reset"].to_i
          sleep_time = [ reset_time - Time.now.to_i, ApiConfiguration::MAX_RETRY_DELAY ].max
          Rails.logger.warn "Rate limited. Sleeping for #{sleep_time}s (attempt #{retries}/#{config.max_retries})"
          sleep(sleep_time)
          retry
        else
          raise
        end
      rescue Octokit::ServerError => e
        if retries < config.max_retries
          retries += 1
          delay = ApiConfiguration::RETRY_BACKOFF_BASE ** retries
          Rails.logger.warn "Server error (#{e.message}). Retrying in #{delay}s (attempt #{retries}/#{config.max_retries})"
          sleep(delay)
          retry
        else
          raise
        end
      end
    end

    def check_rate_limit
      rate_limit = @client.rate_limit
      return unless rate_limit

      remaining = rate_limit.remaining
      limit = rate_limit.limit || 5000 # Default to core API limit if nil
      Rails.logger.debug "Rate limit check: #{remaining}/#{limit} remaining, resets at #{rate_limit.resets_at}"

      # Adjust thresholds based on API type - search API has much lower limits
      critical_threshold = limit <= 100 ? 3 : ApiConfiguration::CRITICAL_RATE_LIMIT_THRESHOLD
      warning_threshold = limit <= 100 ? 10 : ApiConfiguration::WARNING_RATE_LIMIT_THRESHOLD

      if remaining < critical_threshold
        reset_time = rate_limit.resets_at
        sleep_time = [ reset_time - Time.now, ApiConfiguration::MIN_CRITICAL_DELAY ].max
        Rails.logger.warn "Rate limit critical (#{remaining}/#{limit} remaining). Sleeping for #{sleep_time}s until #{reset_time}"
        sleep(sleep_time) if sleep_time > 0
      elsif remaining < warning_threshold
        Rails.logger.debug "Rate limit warning (#{remaining}/#{limit} remaining). Sleeping for #{config.default_rate_limit_delay}s"
        sleep(config.default_rate_limit_delay)
      end
    end

    def normalize_member_data(member)
      {
        github_login: member.login,
        name: member.name,
        avatar_url: member.avatar_url
      }
    end

    def normalize_team_data(team)
      {
        name: team.name,
        github_slug: team.slug,
        description: team.description,
        members_count: team.members_count,
        privacy: team.privacy
      }
    end

    def normalize_issue_data(issue)
      {
        github_issue_number: issue.number,
        github_issue_url: issue.html_url,
        title: issue.title,
        body: issue.body,
        state: issue.state,
        created_at: issue.created_at,
        updated_at: issue.updated_at,
        user: {
          github_login: issue.user.login
        }
      }
    end

    def normalize_user_data(user)
      {
        github_login: user.login,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url,
        company: user.company,
        location: user.location,
        bio: user.bio
      }
    end
  end
end
