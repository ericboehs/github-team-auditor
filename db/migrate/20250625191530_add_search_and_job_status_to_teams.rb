class AddSearchAndJobStatusToTeams < ActiveRecord::Migration[8.0]
  def change
    # Search functionality columns
    add_column :teams, :search_terms, :text
    add_column :teams, :exclusion_terms, :text
    add_column :teams, :search_repository, :string

    # Job status tracking columns
    add_column :teams, :sync_status, :string
    add_column :teams, :sync_started_at, :timestamp
    add_column :teams, :issue_correlation_status, :string
    add_column :teams, :issue_correlation_started_at, :timestamp
    add_column :teams, :issue_correlation_completed_at, :timestamp
    remove_column :teams, :sync_completed_at, :timestamp
  end
end
