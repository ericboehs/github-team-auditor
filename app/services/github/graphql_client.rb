module Github
  class GraphqlClient
    include ActiveSupport::Configurable

    class ConfigurationError < StandardError; end

    config_accessor :default_rate_limit_delay, default: ApiConfiguration::DEFAULT_RATE_LIMIT_DELAY
    config_accessor :max_retries, default: ApiConfiguration::MAX_RETRIES

    def initialize(organization, rate_limit_callback: nil)
      @organization = organization
      @rate_limit_callback = rate_limit_callback
      token = ENV["GHTA_GITHUB_TOKEN"]
      raise ConfigurationError, "GHTA_GITHUB_TOKEN environment variable is required" if token.blank?
      @client = Octokit::Client.new(access_token: token)
      configure_client
    end

    # Batch search for issues mentioning multiple team members
    def batch_search_issues_for_members(team_members, search_terms:, repository:, exclusion_terms: "")
      repo_owner, repo_name = repository.split("/", 2)

      # Build a combined search query that looks for any of the team members
      member_logins = team_members.map(&:github_login)

      # Create batch search queries - GraphQL search supports complex queries
      search_queries = build_batch_search_queries(member_logins, search_terms, repo_owner, repo_name)

      all_results = {}

      search_queries.each do |query_batch|
        # Set the current batch mapping for response processing
        @current_batch_searches = query_batch[:searches]

        with_rate_limiting do
          response = execute_batch_search(query_batch)
          process_batch_search_response(response, all_results, exclusion_terms.downcase)
        end
      end

      all_results
    end

    # Single member search (backward compatibility)
    def search_issues_for_member(github_login, search_terms:, repository:, exclusion_terms: "")
      repo_owner, repo_name = repository.split("/", 2)

      query = build_single_search_query(github_login, search_terms, repo_owner, repo_name)

      with_rate_limiting do
        response = @client.post("/graphql", { query: query[:query], variables: query[:variables] }.to_json)
        issues = extract_issues_from_response(response, query[:search_key])
        filter_excluded_issues(issues, exclusion_terms.downcase)
      end
    end

    private

    def configure_client
      @client.auto_paginate = false # We handle pagination manually for GraphQL
      @client.per_page = ApiConfiguration::DEFAULT_PAGE_SIZE
    end

    def build_batch_search_queries(member_logins, search_terms, repo_owner, repo_name)
      # GraphQL allows up to 5 search queries per request, batch members accordingly
      member_logins.each_slice(5).map do |login_batch|
        build_multi_search_query(login_batch, search_terms, repo_owner, repo_name)
      end
    end

    def build_multi_search_query(member_logins, search_terms, repo_owner, repo_name)
      searches = {}
      variables = {}

      query_parts = member_logins.map.with_index do |login, index|
        search_key = "search#{index}"
        query_string = build_search_string(login, search_terms)

        variables["query#{index}".to_sym] = "repo:#{repo_owner}/#{repo_name} #{query_string}"
        searches[search_key.to_sym] = login

        <<~GRAPHQL
          #{search_key}: search(query: $query#{index}, type: ISSUE, first: 100) {
            nodes {
              ... on Issue {
                number
                title
                bodyText
                url
                createdAt
                updatedAt
                state
                author {
                  login
                }
              }
            }
            issueCount
          }
        GRAPHQL
      end

      query = <<~GRAPHQL
        query BatchIssueSearch(#{variables.keys.map { |k| "$#{k}: String!" }.join(", ")}) {
          #{query_parts.join("\n")}
          rateLimit {
            remaining
            resetAt
            limit
            cost
          }
        }
      GRAPHQL

      { query: query, variables: variables, searches: searches }
    end

    def build_single_search_query(github_login, search_terms, repo_owner, repo_name)
      query_string = build_search_string(github_login, search_terms)
      full_query = "repo:#{repo_owner}/#{repo_name} #{query_string}"

      query = <<~GRAPHQL
        query SingleIssueSearch($query: String!) {
          search(query: $query, type: ISSUE, first: 100) {
            nodes {
              ... on Issue {
                number
                title
                bodyText
                url
                createdAt
                updatedAt
                state
                author {
                  login
                }
              }
            }
            issueCount
          }
          rateLimit {
            remaining
            resetAt
            limit
            cost
          }
        }
      GRAPHQL

      { query: query, variables: { query: full_query }, search_key: :search }
    end

    def build_search_string(github_login, search_terms)
      # Sanitize inputs to prevent query injection
      safe_login = sanitize_search_term(github_login)
      safe_search_terms = sanitize_search_term(search_terms)

      # Build query exactly like the working REST API: search for member in both body and title, plus search terms
      "is:issue \"#{safe_login}\" in:body \"#{safe_login}\" in:title \"#{safe_search_terms}\""
    end

    def sanitize_search_term(term)
      return "" if term.blank?

      # Remove potentially dangerous characters for GitHub search
      sanitized = term.to_s.gsub(/[^\w\s\-\.]/, "")
      sanitized.truncate(100)
    end

    def execute_batch_search(query_batch)
      Rails.logger.info "Executing GraphQL batch search with variables: #{query_batch[:variables].inspect}"
      Rails.logger.debug "GraphQL query: #{query_batch[:query]}"

      response = @client.post("/graphql", { query: query_batch[:query], variables: query_batch[:variables] }.to_json)

      Rails.logger.info "GraphQL response data keys: #{response.dig(:data)&.keys || 'no data'}"
      if response[:errors]
        Rails.logger.error "GraphQL errors: #{response[:errors].inspect}"
      end

      response
    end

    def process_batch_search_response(response, all_results, exclusion_terms)
      return unless response[:data]

      # Update rate limit info
      update_rate_limit_from_response(response)

      # We need to track which search corresponds to which member
      # This should be set by the calling context
      current_batch = @current_batch_searches
      return unless current_batch

      # Process each search result in the batch
      response[:data].each do |search_key, search_result|
        next if search_key == :rateLimit || (!search_result.is_a?(Hash) && !search_result.respond_to?(:nodes))

        # Find which member this search was for
        member_login = current_batch[search_key]
        next unless member_login

        issues = extract_issues_from_search_result(search_result)
        filtered_issues = filter_excluded_issues(issues, exclusion_terms)

        all_results[member_login] = filtered_issues
      end
    end

    def extract_issues_from_response(response, search_key)
      return [] unless response[:data]&.dig(search_key, :nodes)

      # Update rate limit info
      update_rate_limit_from_response(response)

      extract_issues_from_search_result(response[:data][search_key])
    end

    def extract_issues_from_search_result(search_result)
      return [] unless search_result[:nodes]

      search_result[:nodes].map do |issue|
        normalize_issue_data_from_graphql(issue)
      end
    end

    def normalize_issue_data_from_graphql(issue)
      {
        github_issue_number: issue[:number],
        github_issue_url: issue[:url],
        title: issue[:title],
        body: issue[:bodyText],
        state: issue[:state]&.downcase,
        created_at: Time.parse(issue[:createdAt]),
        updated_at: Time.parse(issue[:updatedAt]),
        user: {
          github_login: issue.dig(:author, :login)
        }
      }
    end

    def filter_excluded_issues(issues, exclusion_terms)
      return issues if exclusion_terms.blank?

      issues.reject do |issue|
        title_lower = issue[:title].to_s.downcase
        title_lower.include?(exclusion_terms)
      end
    end

    def find_member_for_search_key(search_key)
      # This will be set by the calling method when processing batch responses
      @current_batch_searches&.dig(search_key)
    end

    def update_rate_limit_from_response(response)
      rate_limit = response.dig(:data, :rateLimit)
      return unless rate_limit

      remaining = rate_limit[:remaining]
      limit = rate_limit[:limit]
      cost = rate_limit[:cost]

      Rails.logger.debug "GraphQL rate limit: #{remaining}/#{limit} remaining (cost: #{cost})"

      # GraphQL uses a points system - much more generous than REST
      # Cost is typically 1 point per search, with 5000 points per hour
      if remaining < 100
        reset_time = Time.parse(rate_limit[:resetAt])
        sleep_time = [ reset_time - Time.now, 1.0 ].max
        Rails.logger.warn "GraphQL rate limit low (#{remaining}/#{limit} remaining). Sleeping for #{sleep_time}s"
        sleep_with_countdown(sleep_time) if sleep_time > 0
      end
    end

    def with_rate_limiting(&block)
      retries = 0
      begin
        yield
      rescue Octokit::TooManyRequests => e
        if retries < config.max_retries
          retries += 1
          reset_time = e.response_headers["x-ratelimit-reset"].to_i
          sleep_time = [ reset_time - Time.now.to_i, ApiConfiguration::MAX_RETRY_DELAY ].max
          Rails.logger.warn "GraphQL rate limited. Sleeping for #{sleep_time}s (attempt #{retries}/#{config.max_retries})"
          sleep_with_countdown(sleep_time)
          retry
        else
          raise
        end
      rescue Octokit::ServerError => e
        if retries < config.max_retries
          retries += 1
          delay = ApiConfiguration::RETRY_BACKOFF_BASE ** retries
          Rails.logger.warn "GraphQL server error (#{e.message}). Retrying in #{delay}s (attempt #{retries}/#{config.max_retries})"
          sleep(delay)
          retry
        else
          raise
        end
      end
    end

    def sleep_with_countdown(sleep_time)
      return if sleep_time <= 0

      if @rate_limit_callback
        total_seconds = sleep_time.to_i
        (total_seconds).downto(1) do |remaining_seconds|
          @rate_limit_callback.call(remaining_seconds)
          sleep(1)
        end
        @rate_limit_callback.call(0) # Clear the countdown
      else
        sleep(sleep_time)
      end
    end
  end
end
