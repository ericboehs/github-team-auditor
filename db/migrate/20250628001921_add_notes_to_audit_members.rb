class AddNotesToAuditMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_members, :notes, :text
  end
end
