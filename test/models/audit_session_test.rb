require "test_helper"

class AuditSessionTest < ActiveSupport::TestCase
  setup do
    @audit_session = audit_sessions(:q1_2025_audit)
  end

  test "should be valid" do
    assert @audit_session.valid?
  end

  test "should require name" do
    @audit_session.name = nil
    assert_not @audit_session.valid?
    assert_includes @audit_session.errors[:name], "can't be blank"
  end

  test "should require status" do
    @audit_session.status = nil
    assert_not @audit_session.valid?
    assert_includes @audit_session.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @audit_session.status = "invalid"
    assert_not @audit_session.valid?
    assert_includes @audit_session.errors[:status], "is not included in the list"
  end

  test "complete! should update status and completed_at" do
    @audit_session.complete!
    @audit_session.reload

    assert_equal "completed", @audit_session.status
    assert_not_nil @audit_session.completed_at
    assert_in_delta Time.current, @audit_session.completed_at, 5.seconds
  end

  test "progress_percentage should return 0 when no active members" do
    # Create audit session with no members
    audit_session = AuditSession.create!(
      organization: organizations(:va),
      user: users(:one),
      team: teams(:platform_security),
      name: "Empty audit",
      status: "draft"
    )

    assert_equal 0, audit_session.progress_percentage
  end

  test "progress_percentage should calculate correctly" do
    # Check the actual fixture data
    active_members = @audit_session.audit_members.active
    validated_members = active_members.where.not(access_validated: nil)

    expected_percentage = (validated_members.count.to_f / active_members.count * 100).round(1)
    progress = @audit_session.progress_percentage
    assert_equal expected_percentage, progress
  end

  test "maintainer_members should return members with maintainer role" do
    maintainers = @audit_session.maintainer_members
    assert_equal 1, maintainers.count
    assert_equal "john_doe", maintainers.first.github_login
  end

  test "government_employee_maintainers should return government employee maintainers" do
    gov_maintainers = @audit_session.government_employee_maintainers
    assert_equal 1, gov_maintainers.count
    assert_equal "john_doe", gov_maintainers.first.github_login
    assert gov_maintainers.first.government_employee
  end

  test "compliance_ready? should return true when at least 2 maintainers and 1 government employee" do
    # Add another maintainer who is a government employee
    @audit_session.audit_members.create!(
      github_login: "gov_maintainer",
      name: "Gov Maintainer",
      avatar_url: "https://github.com/gov_maintainer.png",
      maintainer_role: true,
      government_employee: true,
      removed: false
    )

    assert @audit_session.compliance_ready?
  end

  test "compliance_ready? should return false when not enough maintainers" do
    # Current fixture has only 1 maintainer
    assert_not @audit_session.compliance_ready?
  end

  test "scopes should work correctly" do
    assert_includes AuditSession.active, @audit_session
    assert_includes AuditSession.recent.first(3), @audit_session
  end
end
