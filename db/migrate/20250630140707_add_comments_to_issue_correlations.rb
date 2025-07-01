class AddCommentsToIssueCorrelations < ActiveRecord::Migration[8.0]
  def change
    add_column :issue_correlations, :comments, :text
  end
end
