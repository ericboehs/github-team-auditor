class AddSearchTermsToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :search_terms, :text
    add_column :teams, :exclusion_terms, :text
    add_column :teams, :search_repository, :string
  end
end
