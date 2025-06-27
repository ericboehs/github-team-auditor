class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name
      t.string :github_slug
      t.text :description
      t.datetime :sync_completed_at

      t.timestamps
    end
  end
end
