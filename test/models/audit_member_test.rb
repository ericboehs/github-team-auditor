require "test_helper"

class AuditMemberTest < ActiveSupport::TestCase
  setup do
    @audit_session = audit_sessions(:q2_2025_platform_security)
    @team_member = team_members(:john_doe_team_member)
    @audit_member = AuditMember.new(
      audit_session: @audit_session,
      team_member: @team_member
    )
  end

  test "validation_status returns validated when access_validated is true" do
    @audit_member.access_validated = true
    assert_equal "validated", @audit_member.validation_status
  end

  test "validation_status returns pending when access_validated is false" do
    @audit_member.access_validated = false
    assert_equal "pending", @audit_member.validation_status
  end

  test "validation_status returns pending when access_validated is nil" do
    @audit_member.access_validated = nil
    assert_equal "pending", @audit_member.validation_status
  end

  test "removed? returns true when removed is true" do
    @audit_member.removed = true
    assert @audit_member.removed?
  end

  test "removed? returns false when removed is false" do
    @audit_member.removed = false
    refute @audit_member.removed?
  end

  test "removed? returns false when removed is nil" do
    @audit_member.removed = nil
    refute @audit_member.removed?
  end

  test "soft_delete! sets removed to true" do
    @audit_member.save!
    @audit_member.soft_delete!
    assert @audit_member.removed?
  end

  test "restore! sets removed to false" do
    @audit_member.removed = true
    @audit_member.save!
    @audit_member.restore!
    refute @audit_member.removed?
  end

  test "delegates to team_member correctly" do
    assert_equal @team_member.github_login, @audit_member.github_login
    assert_equal @team_member.name, @audit_member.name
    assert_equal @team_member.github_url, @audit_member.github_url
    assert_equal @team_member.display_name, @audit_member.display_name
  end

  test "scopes work correctly" do
    team_member1 = TeamMember.create!(
      team: @audit_session.team,
      github_login: "user1",
      maintainer_role: true,
      government_employee: true
    )

    team_member2 = TeamMember.create!(
      team: @audit_session.team,
      github_login: "user2",
      maintainer_role: false,
      government_employee: false
    )

    member1 = AuditMember.create!(
      audit_session: @audit_session,
      team_member: team_member1,
      access_validated: true,
      removed: false
    )

    member2 = AuditMember.create!(
      audit_session: @audit_session,
      team_member: team_member2,
      access_validated: false,
      removed: true
    )

    assert_includes AuditMember.validated, member1
    refute_includes AuditMember.validated, member2

    assert_includes AuditMember.pending_validation, member2
    refute_includes AuditMember.pending_validation, member1

    assert_includes AuditMember.active, member1
    refute_includes AuditMember.active, member2

    assert_includes AuditMember.removed, member2
    refute_includes AuditMember.removed, member1

    assert_includes AuditMember.maintainers, member1
    refute_includes AuditMember.maintainers, member2

    assert_includes AuditMember.government_employees, member1
    refute_includes AuditMember.government_employees, member2
  end

  test "team_member association works" do
    assert_equal @team_member, @audit_member.team_member
    assert_equal @team_member.github_login, @audit_member.github_login
  end

  test "issue delegation works correctly" do
    issues = @audit_member.open_issues
    assert_respond_to issues, :count

    resolved_issues = @audit_member.resolved_issues
    assert_respond_to resolved_issues, :count

    result = @audit_member.has_open_issues?
    assert [ true, false ].include?(result)
  end

  test "validates notes length" do
    @audit_member.notes = "a" * 1000
    assert @audit_member.valid?

    @audit_member.notes = "a" * 1001
    refute @audit_member.valid?
    assert_includes @audit_member.errors[:notes], "is too long (maximum is 1000 characters)"
  end

  test "validates comment length" do
    @audit_member.comment = "a" * 1000
    assert @audit_member.valid?

    @audit_member.comment = "a" * 1001
    refute @audit_member.valid?
    assert_includes @audit_member.errors[:comment], "is too long (maximum is 1000 characters)"
  end

  test "notes_updated_by association works" do
    user = users(:one)
    @audit_member.notes_updated_by = user
    @audit_member.save!

    assert_equal user, @audit_member.notes_updated_by
    assert_equal user.email_address, @audit_member.notes_updated_by.email_address
  end

  test "notes_updated_by can be nil" do
    @audit_member.notes_updated_by = nil
    assert @audit_member.valid?
    @audit_member.save!

    assert_nil @audit_member.notes_updated_by
  end

  test "notes_updated_at can be set" do
    time = 1.hour.ago
    @audit_member.notes_updated_at = time
    @audit_member.save!

    assert_equal time.to_i, @audit_member.notes_updated_at.to_i
  end
end
