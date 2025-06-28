class AddNotesMetadataToAuditMembers < ActiveRecord::Migration[8.0]
  def change
    add_reference :audit_members, :notes_updated_by, null: true, foreign_key: { to_table: :users }
    add_column :audit_members, :notes_updated_at, :datetime
  end
end
