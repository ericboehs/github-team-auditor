class AddIndexesToTeamMembersAndAuditMembers < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for frequently sorted columns in team_members table
    add_index :team_members, :github_login, name: "index_team_members_on_github_login"
    add_index :team_members, :maintainer_role, name: "index_team_members_on_maintainer_role"
    
    # Add index for frequently sorted column in audit_members table
    add_index :audit_members, :access_validated, name: "index_audit_members_on_access_validated"
  end
end
