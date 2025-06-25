class CreateIssueCorrelations < ActiveRecord::Migration[8.0]
  def change
    create_table :issue_correlations do |t|
      t.references :team_member, null: false, foreign_key: true
      t.integer :github_issue_number
      t.string :github_issue_url
      t.string :title
      t.text :description
      t.string :status, default: 'open'
      t.datetime :resolved_at
      t.datetime :issue_created_at
      t.datetime :issue_updated_at

      t.timestamps
    end

    add_index :issue_correlations, [ :team_member_id, :github_issue_number ], unique: true, name: "index_issue_correlations_on_member_and_issue"
  end
end
