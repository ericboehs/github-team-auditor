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

  test "should update notes via JSON request" do
    assert_nil @audit_member.notes
    assert_nil @audit_member.notes_updated_by
    assert_nil @audit_member.notes_updated_at

    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "Test note content" } },
          headers: { "Content-Type": "application/json" },
          as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]

    @audit_member.reload
    assert_equal "Test note content", @audit_member.notes
    assert_equal @user, @audit_member.notes_updated_by
    assert_not_nil @audit_member.notes_updated_at
    assert_in_delta Time.current, @audit_member.notes_updated_at, 5.seconds
  end

  test "should update notes metadata only when notes change" do
    @audit_member.update!(notes: "Original note")
    original_time = @audit_member.notes_updated_at

    # Update with same content
    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "Original note" } },
          headers: { "Content-Type": "application/json" },
          as: :json

    @audit_member.reload
    assert_equal original_time.to_i, @audit_member.notes_updated_at.to_i

    # Update with different content
    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "Updated note" } },
          headers: { "Content-Type": "application/json" },
          as: :json

    @audit_member.reload
    assert_equal "Updated note", @audit_member.notes
    assert_not_equal original_time, @audit_member.notes_updated_at
  end

  test "should clear notes when empty string is provided" do
    @audit_member.update!(notes: "Some note")

    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "" } },
          headers: { "Content-Type": "application/json" },
          as: :json

    assert_response :success
    @audit_member.reload
    assert_equal "", @audit_member.notes
  end

  test "should return error for invalid notes" do
    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "a" * 1001 } },
          headers: { "Content-Type": "application/json" },
          as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_includes response_data["errors"]["notes"], "is too long (maximum is 1000 characters)"

    @audit_member.reload
    assert_nil @audit_member.notes
  end

  test "should handle turbo stream requests for notes update" do
    patch audit_member_path(@audit_member),
          params: { audit_member: { notes: "Test note" } },
          headers: { "Accept": "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "turbo-stream", response.body
    
    @audit_member.reload
    assert_equal "Test note", @audit_member.notes
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
