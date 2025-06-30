class AddCommentAuthorsToIssueCorrelations < ActiveRecord::Migration[8.0]
  def change
    add_column :issue_correlations, :comment_authors, :text, comment: "JSON array of comment author usernames corresponding to comments"
  end
end
