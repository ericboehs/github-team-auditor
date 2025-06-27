class AddSearchAndJobStatusToTeams < ActiveRecord::Migration[8.0]
  def change
    # Search functionality columns
    add_column :teams, :search_terms, :text
    add_column :teams, :exclusion_terms, :text
    add_column :teams, :search_repository, :string

    # Job status tracking columns
    add_column :teams, :sync_status, :string
    add_column :teams, :sync_completed_at, :timestamp
    add_column :teams, :issue_correlation_status, :string
    add_column :teams, :issue_correlation_completed_at, :timestamp

    # Replace last_synced_at with sync_completed_at for consistency
    remove_column :teams, :last_synced_at, :timestamp
  end
end
