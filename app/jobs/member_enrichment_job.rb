class MemberEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on Github::ApiClient::ConfigurationError

  GOVERNMENT_DOMAINS = %w[.gov .mil va.gov].freeze
  GOVERNMENT_COMPANIES = [
    "Department of Veterans Affairs",
    "U.S. Department of Veterans Affairs",
    "VA",
    "Veterans Affairs"
  ].freeze

  def perform(team_id, member_github_logins = nil)
    team = Team.find(team_id)

    # If specific members provided, only enrich those, otherwise enrich all missing data
    members_to_enrich = if member_github_logins.present?
      team.team_members.where(github_login: member_github_logins)
    else
      team.team_members.where(government_employee: nil).or(
        team.team_members.where(name: nil)
      )
    end

    return if members_to_enrich.empty?

    Rails.logger.info "Starting member enrichment for #{members_to_enrich.count} members in team: #{team.name}"

    api_client = Github::ApiClient.new(team.organization)
    enriched_count = 0

    members_to_enrich.find_each do |member|
      user_details = api_client.user_details(member.github_login)

      if user_details
        member.update!(
          name: user_details[:name] || member.name,
          government_employee: detect_government_employee(user_details)
        )
        enriched_count += 1
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to enrich member #{member.github_login}: #{e.message}"
      # Continue with other members
    end

    Rails.logger.info "Member enrichment completed: #{enriched_count}/#{members_to_enrich.count} members enriched"
  end

  private

  def detect_government_employee(user_details)
    return false unless user_details

    email = user_details[:email]
    company = user_details[:company]

    government_domains = GOVERNMENT_DOMAINS
    government_companies = GOVERNMENT_COMPANIES

    if email
      return true if government_domains.any? { |domain| email.downcase.include?(domain) }
    end

    if company
      return true if government_companies.any? { |gov_company| company.downcase.include?(gov_company.downcase) }
    end

    false
  end
end
