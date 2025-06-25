class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :github_login
      t.text :settings

      t.timestamps
    end
  end
end
