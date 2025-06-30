namespace :teams do
  desc "Clear all failed team job states (sync_status and issue_correlation_status)"
  task clear_failed_jobs: :environment do
    puts "Clearing failed job states..."

    failed_sync_teams = Team.where(sync_status: "failed")
    failed_correlation_teams = Team.where(issue_correlation_status: "failed")

    failed_sync_teams.each do |team|
      puts "  Clearing failed sync_status for team: #{team.name} (ID: #{team.id})"
      team.update!(sync_status: nil)
    end

    failed_correlation_teams.each do |team|
      puts "  Clearing failed issue_correlation_status for team: #{team.name} (ID: #{team.id})"
      team.update!(issue_correlation_status: nil)
    end

    total_cleared = failed_sync_teams.count + failed_correlation_teams.count
    puts "Done! Cleared #{total_cleared} failed job states."
    puts "All teams should be ready for new operations."
  end

  desc "Show job status for all teams"
  task job_status: :environment do
    puts "Team Job Status Report"
    puts "=" * 50

    Team.includes(:organization).find_each do |team|
      status_parts = []
      status_parts << "sync: #{team.sync_status}" if team.sync_status.present?
      status_parts << "correlation: #{team.issue_correlation_status}" if team.issue_correlation_status.present?

      if status_parts.any?
        puts "#{team.organization.name}/#{team.name} (ID: #{team.id})"
        puts "  Status: #{status_parts.join(', ')}"
      end
    end

    running_count = Team.where.not(sync_status: nil).or(Team.where.not(issue_correlation_status: nil)).count
    if running_count == 0
      puts "No teams have active job states."
    end
  end
end
