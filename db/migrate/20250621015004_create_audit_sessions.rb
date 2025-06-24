class CreateAuditSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_sessions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.date :due_date
      t.text :notes

      t.timestamps
    end
  end
end
