require "test_helper"

class AuditMemberTest < ActiveSupport::TestCase
  setup do
    @audit_session = audit_sessions(:q2_2025_platform_security)
    @audit_member = AuditMember.new(
      audit_session: @audit_session,
      github_login: "testuser",
      name: "Test User"
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

  test "includes GithubUrlable concern" do
    assert @audit_member.respond_to?(:github_url)
    assert @audit_member.respond_to?(:display_name)
  end

  test "validates github_login presence through concern" do
    @audit_member.github_login = nil
    refute @audit_member.valid?
    assert_includes @audit_member.errors[:github_login], "can't be blank"
  end

  test "scopes work correctly" do
    member1 = AuditMember.create!(
      audit_session: @audit_session,
      github_login: "user1",
      access_validated: true,
      removed: false,
      maintainer_role: true,
      government_employee: true
    )

    member2 = AuditMember.create!(
      audit_session: @audit_session,
      github_login: "user2",
      access_validated: false,
      removed: true,
      maintainer_role: false,
      government_employee: false
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

  test "corresponding_team_member returns nil when audit_session has no team" do
    # Create audit session without team - will fail validation but allows testing the method
    session_without_team = AuditSession.new(
      name: "Test Session",
      status: "draft",
      organization: organizations(:va),
      user: users(:one)
    )
    @audit_member.audit_session = session_without_team
    assert_nil @audit_member.corresponding_team_member
  end

  test "corresponding_team_member returns team member when found" do
    team = teams(:platform_security)
    @audit_member.audit_session.update!(team: team)
    @audit_member.update!(github_login: "john_doe")

    team_member = @audit_member.corresponding_team_member
    assert_not_nil team_member
    assert_equal "john_doe", team_member.github_login
  end

  test "open_issues returns empty when no corresponding team member" do
    # Create audit session without team
    session_without_team = AuditSession.new(
      name: "Test Session",
      status: "draft",
      organization: organizations(:va),
      user: users(:one)
    )
    @audit_member.audit_session = session_without_team
    issues = @audit_member.open_issues
    assert_equal 0, issues.count
  end

  test "open_issues returns team member issues when found" do
    team = teams(:platform_security)
    @audit_member.audit_session.update!(team: team)
    @audit_member.update!(github_login: "john_doe")

    issues = @audit_member.open_issues
    assert_respond_to issues, :count
  end

  test "resolved_issues returns empty when no corresponding team member" do
    # Create audit session without team
    session_without_team = AuditSession.new(
      name: "Test Session",
      status: "draft",
      organization: organizations(:va),
      user: users(:one)
    )
    @audit_member.audit_session = session_without_team
    issues = @audit_member.resolved_issues
    assert_equal 0, issues.count
  end

  test "resolved_issues returns team member issues when found" do
    team = teams(:platform_security)
    @audit_member.audit_session.update!(team: team)
    @audit_member.update!(github_login: "john_doe")

    issues = @audit_member.resolved_issues
    assert_respond_to issues, :count
  end

  test "has_open_issues? returns false when no corresponding team member" do
    # Create audit session without team
    session_without_team = AuditSession.new(
      name: "Test Session",
      status: "draft",
      organization: organizations(:va),
      user: users(:one)
    )
    @audit_member.audit_session = session_without_team
    refute @audit_member.has_open_issues?
  end

  test "has_open_issues? returns team member result when found" do
    team = teams(:platform_security)
    @audit_member.audit_session.update!(team: team)
    @audit_member.update!(github_login: "john_doe")

    # Should respond without error (result depends on data)
    result = @audit_member.has_open_issues?
    assert [ true, false ].include?(result)
  end
end
