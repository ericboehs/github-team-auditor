class CreateTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :team_members do |t|
      t.references :team, null: false, foreign_key: true
      t.string :github_login
      t.string :name
      t.string :avatar_url
      t.boolean :maintainer_role
      t.boolean :government_employee
      t.boolean :active, default: true, null: false
      t.datetime :last_seen_at
      t.datetime :first_seen_at

      t.timestamps
    end

    add_index :team_members, [ :team_id, :github_login ], unique: true, name: "index_team_members_on_team_id_and_github_login"
  end
end
