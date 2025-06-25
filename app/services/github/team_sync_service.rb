module Github
  class TeamSyncService
    def initialize(team)
      @team = team
      @organization = team.organization
      @api_client = ApiClient.new(@organization)
    end

    def sync_team_members
      Rails.logger.info "Starting team member sync for #{@team.name} (#{@team.github_slug})"

      github_members = fetch_github_members

      # Safety check: prevent accidentally wiping members when API returns empty
      if github_members.empty? && @team.team_members.exists?
        Rails.logger.warn "GitHub API returned 0 members but team currently has #{@team.team_members.count} members. Aborting sync to prevent data loss."
        raise "API returned empty member list - possible API issue or incorrect team configuration"
      end

      sync_results = process_members(github_members)

      # Update audit members in active audit sessions
      sync_active_audit_members

      Rails.logger.info "Sync completed: #{sync_results[:total]} total, #{sync_results[:new_members]} new, #{sync_results[:updated]} updated"
      sync_results
    end

    private

    def fetch_github_members
      @api_client.fetch_team_members(@team.github_slug)
    rescue StandardError => e
      Rails.logger.error "Failed to fetch team members: #{e.message}"
      raise e
    end

    def process_members(github_members)
      current_time = Time.current

      # Get existing members for comparison (by github_login for better reliability)
      existing_members = @team.team_members.where(github_login: github_members.map { |m| m[:github_login] }).index_by(&:github_login)

      # Prepare all member data for upsert (both new and existing)
      upsert_data = github_members.map do |member_data|
        existing_member = existing_members[member_data[:github_login]]

        {
          team_id: @team.id,
          github_login: member_data[:github_login],
          name: member_data[:name],
          avatar_url: member_data[:avatar_url],
          maintainer_role: member_data[:maintainer_role],
          government_employee: existing_member&.government_employee || false, # Preserve existing or default
          active: true, # Mark as active since they're in the current GitHub response
          created_at: existing_member&.created_at || current_time, # Preserve existing or set new
          updated_at: current_time # Always update
        }
      end

      # Get the count of existing vs new members for reporting
      new_member_count = github_members.count { |m| !existing_members.key?(m[:github_login]) }

      # Upsert all members in one batch operation (using github_login as primary unique key)
      TeamMember.upsert_all(
        upsert_data,
        unique_by: [ :team_id, :github_login ]
      )

      mark_absent_members(github_members.map { |m| m[:github_login] })

      # Enrich new members with detailed user info in background
      if new_member_count > 0
        new_member_logins = github_members
          .select { |m| !existing_members.key?(m[:github_login]) }
          .map { |m| m[:github_login] }
        MemberEnrichmentJob.perform_later(@team.id, new_member_logins)
      end

      {
        total: github_members.size,
        new_members: new_member_count,
        updated: github_members.size - new_member_count
      }
    end

    def mark_absent_members(current_github_logins)
      absent_members = @team.team_members.where.not(github_login: current_github_logins)
      absent_members.update_all(active: false) if absent_members.any?
    end

    def sync_active_audit_members
      # Find active and draft audit sessions for this team
      active_audits = @team.audit_sessions.where(status: %w[active draft])

      return if active_audits.empty?

      Rails.logger.info "Syncing audit members for #{active_audits.count} active/draft audit sessions"

      active_audits.find_each do |audit_session|
        sync_audit_session_members(audit_session)
      end
    end

    def sync_audit_session_members(audit_session)
      # Add new team members to the audit session
      current_team_members = @team.team_members.current

      current_team_members.find_each do |team_member|
        audit_session.audit_members.find_or_create_by!(team_member: team_member) do |audit_member|
          audit_member.access_validated = nil
          audit_member.removed = false
        end
      end

      # Mark audit members as removed if their corresponding team member is no longer active
      inactive_team_member_ids = @team.team_members.where(active: false).pluck(:id)
      if inactive_team_member_ids.any?
        audit_session.audit_members
          .where(team_member_id: inactive_team_member_ids)
          .where(removed: false)
          .update_all(removed: true)
      end
    end
  end
end
