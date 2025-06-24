class CreateAuditMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_members do |t|
      t.references :audit_session, null: false, foreign_key: true
      t.string :github_login
      t.string :name
      t.string :avatar_url
      t.boolean :access_validated
      t.boolean :removed
      t.boolean :maintainer_role
      t.boolean :government_employee
      t.datetime :last_seen_at
      t.datetime :first_seen_at

      t.timestamps
    end
  end
end
