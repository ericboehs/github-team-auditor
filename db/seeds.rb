# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user for development
if Rails.env.development?
  admin_user = User.find_or_create_by!(email_address: "admin@example.com") do |user|
    user.password = "password"
    user.admin = true
  end

  puts "Created admin user: #{admin_user.email_address}"
  puts "Password: password"
  puts "Admin: #{admin_user.admin?}"
end

# Create sample organizations and teams for development
if Rails.env.development?
  puts "\nCreating sample organizations and teams for development..."

  va_org = Organization.find_or_create_by!(github_login: "department-of-veterans-affairs") do |org|
    org.name = "Department of Veterans Affairs"
  end

  # Create sample teams
  vets_api_prod_terminal = va_org.teams.find_or_create_by!(github_slug: "dsva-vagov-vets-api-prod-rw") do |team|
    team.name = "Vets API Prod Terminal"
    team.description = "Vets API Production Terminal Access Team"
  end

  vets_api_sidekiq_ui = va_org.teams.find_or_create_by!(github_slug: "va-gov-sidekiq-prod") do |team|
    team.name = "Vets API Prod Sidekiq UI"
    team.description = "Vets API Production Sidekiq UI Access Team"
  end

  # Create sample audit sessions
  if User.any?
    first_user = User.first

    # Completed audit session
    completed_audit = AuditSession.find_or_create_by!(
      name: "Q4 2024 Vets API Prod Terminal Audit",
      organization: va_org,
      team: vets_api_prod_terminal,
      user: first_user
    ) do |session|
      session.status = "completed"
      session.started_at = 3.months.ago
      session.completed_at = 2.months.ago
    end

    # Active audit session
    active_audit = AuditSession.find_or_create_by!(
      name: "Q1 2025 Vets API Prod Terminal Audit",
      organization: va_org,
      team: vets_api_prod_terminal,
      user: first_user
    ) do |session|
      session.status = "active"
      session.started_at = 1.week.ago
    end

    # Create some sample audit members for the active session
    sample_members = [
      { github_login: "john_doe", name: "John Doe", access_validated: true, maintainer_role: true, government_employee: true },
      { github_login: "jane_smith", name: "Jane Smith", access_validated: false, maintainer_role: false, government_employee: false },
      { github_login: "bob_wilson", name: "Bob Wilson", access_validated: true, maintainer_role: false, government_employee: true }
    ]

    sample_members.each do |member_data|
      # First create or find the team member
      team_member = vets_api_prod_terminal.team_members.find_or_create_by!(github_login: member_data[:github_login]) do |tm|
        tm.name = member_data[:name]
        tm.avatar_url = "https://github.com/#{member_data[:github_login]}.png"
        tm.maintainer_role = member_data[:maintainer_role]
        tm.government_employee = member_data[:government_employee]
      end

      # Then create the audit member referencing the team member
      active_audit.audit_members.find_or_create_by!(team_member: team_member) do |audit_member|
        audit_member.access_validated = member_data[:access_validated]
        audit_member.removed = false
      end
    end

    puts "✅ Created sample audit sessions with members"
  end

  puts "✅ Created #{Organization.count} organizations with #{Team.count} teams"
  puts "✅ Created #{AuditSession.count} audit sessions with #{AuditMember.count} audit members"
end
