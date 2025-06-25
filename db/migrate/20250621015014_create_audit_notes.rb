class CreateAuditNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_notes do |t|
      t.references :audit_member, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
