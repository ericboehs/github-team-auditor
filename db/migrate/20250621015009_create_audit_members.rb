class CreateAuditMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_members do |t|
      t.references :audit_session, null: false, foreign_key: true
      t.references :team_member, null: false, foreign_key: true
      t.boolean :access_validated
      t.boolean :removed
      t.text :comment

      t.timestamps
    end

    add_index :audit_members, [ :audit_session_id, :team_member_id ], unique: true, name: "index_audit_members_on_session_and_member"
  end
end
