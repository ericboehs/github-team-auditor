require "test_helper"

class AuditMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @audit_session = audit_sessions(:q2_2025_platform_security)
    @team_member = team_members(:john_doe_team_member)
    @audit_member = AuditMember.create!(
      audit_session: @audit_session,
      team_member: @team_member,
      access_validated: nil,
      removed: false
    )
  end

  test "should toggle from pending to validated" do
    assert_nil @audit_member.access_validated
    assert_equal "pending", @audit_member.validation_status

    patch toggle_status_audit_member_path(@audit_member)
    @audit_member.reload

    assert_equal true, @audit_member.access_validated
    assert_equal "validated", @audit_member.validation_status
  end

  test "should toggle from validated to removed" do
    @audit_member.update!(access_validated: true)
    assert_equal "validated", @audit_member.validation_status

    patch toggle_status_audit_member_path(@audit_member)
    @audit_member.reload

    assert_equal true, @audit_member.removed
    assert @audit_member.removed?
  end

  test "should toggle from removed back to pending" do
    @audit_member.update!(removed: true)
    assert @audit_member.removed?

    patch toggle_status_audit_member_path(@audit_member)
    @audit_member.reload

    assert_equal false, @audit_member.removed
    assert_nil @audit_member.access_validated
    assert_equal "pending", @audit_member.validation_status
  end

  test "should redirect to audit session after toggle" do
    patch toggle_status_audit_member_path(@audit_member)
    assert_redirected_to audit_path(@audit_session)
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
