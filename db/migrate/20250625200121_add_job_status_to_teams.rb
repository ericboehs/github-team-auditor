class AddJobStatusToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :sync_status, :string
    add_column :teams, :sync_started_at, :timestamp
    add_column :teams, :issue_correlation_status, :string
    add_column :teams, :issue_correlation_started_at, :timestamp
    add_column :teams, :issue_correlation_completed_at, :timestamp
    remove_column :teams, :sync_completed_at, :timestamp
  end
end
