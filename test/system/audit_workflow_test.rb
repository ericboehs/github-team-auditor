require "application_system_test_case"

class AuditWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @organization = organizations(:va)
    @team = teams(:platform_security)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "user can create and view audit session" do
    sign_in_as(@user)

    visit audits_path

    assert_text I18n.t("audits.index.title")

    click_on I18n.t("audits.index.new_button")

    fill_in "Name", with: "Test Audit Session"
    select @organization.name, from: "audit_session_organization_id"

    # The team select should now be disabled as teams are not auto-populated
    # Navigate directly to the form with team_id to test the full flow
    visit new_audit_path(team_id: @team.id)

    fill_in "Name", with: "Test Audit Session"
    # Organization and team should be pre-selected
    assert_selector "select#audit_session_organization_id option[selected]", text: @organization.name
    assert_selector "select#audit_session_team_id option[selected]", text: @team.name_with_slug

    fill_in "Notes", with: "Test notes for audit"

    click_on "Create Audit Session"

    assert_text "Test Audit Session"
    assert_text "Test notes for audit"

    # Now that we auto-sync team members, we should see them
    assert_text "Members"
    assert_text "Jane Smith"
    assert_text "John Doe"
  end

  test "user can navigate audit session details" do
    audit_session = AuditSession.create!(
      name: "System Test Audit",
      organization: @organization,
      team: @team,
      user: @user,
      status: "active"
    )

    # Create a team member first
    team_member = @team.team_members.create!(
      github_login: "systemtestuser",
      name: "System Test User",
      avatar_url: "https://github.com/systemtestuser.png",
      maintainer_role: true
    )

    # Add an audit member for the audit session
    audit_member = audit_session.audit_members.create!(
      team_member: team_member,
      access_validated: true
    )

    sign_in_as(@user)

    visit audit_path(audit_session)

    assert_text "System Test Audit"
    assert_text "System Test User"
    assert_text "@systemtestuser"
    assert_text "Maintainer"
    assert_text "Validated"

    # Check progress calculation
    assert_text "100%"
  end

  test "user can set due date for audit session" do
    audit_session = AuditSession.create!(
      name: "Test Due Date Audit",
      organization: @organization,
      team: @team,
      user: @user,
      status: "active"
    )

    sign_in_as(@user)
    visit audit_path(audit_session)

    # Click Set Due Date button
    click_button "Set Due Date"

    # Form should now be visible
    assert_selector "#due-date-form", visible: true

    # Set a due date
    fill_in "audit_session_due_date", with: "2025-12-31"

    click_button "Save"

    # Should redirect back and show success message
    assert_text I18n.t("flash.audits.updated")

    # Reload to verify due date was saved (just check it's not nil)
    visit audit_path(audit_session)
    audit_session.reload
    assert_not_nil audit_session.due_date
  end

  test "user can delete audit session from show page" do
    audit_session = AuditSession.create!(
      name: "Test Delete Audit",
      organization: @organization,
      team: @team,
      user: @user,
      status: "active"
    )

    sign_in_as(@user)
    visit audit_path(audit_session)

    # Should have delete button
    assert_button "Delete"

    # Accept the confirmation dialog and delete
    accept_confirm do
      click_button "Delete"
    end

    # Should redirect to audits index
    assert_current_path audits_path
    assert_text I18n.t("flash.audits.deleted")

    # Audit should be deleted
    assert_not AuditSession.exists?(audit_session.id)
  end

  test "user can cancel due date setting" do
    audit_session = AuditSession.create!(
      name: "Test Cancel Due Date",
      organization: @organization,
      team: @team,
      user: @user,
      status: "active"
    )

    sign_in_as(@user)
    visit audit_path(audit_session)

    # Click Set Due Date button
    click_button "Set Due Date"

    # Form should now be visible
    assert_selector "#due-date-form", visible: true

    # Click Cancel button
    click_button "Cancel"

    # Form should be hidden again
    assert_selector "#due-date-form", visible: false
  end

  private

  def sign_in_as(user)
    visit new_session_path

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"

    click_button I18n.t("auth.sign_in.submit_button")

    # Wait for redirect to complete
    assert_current_path "/"
  end
end
