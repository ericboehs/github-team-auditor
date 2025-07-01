class AddIssueAuthorToIssueCorrelations < ActiveRecord::Migration[8.0]
  def change
    add_column :issue_correlations, :issue_author, :string
  end
end
