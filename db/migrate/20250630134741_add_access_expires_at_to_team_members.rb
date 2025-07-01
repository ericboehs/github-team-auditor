class AddAccessExpiresAtToTeamMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :team_members, :access_expires_at, :datetime
    add_index :team_members, :access_expires_at
  end
end
