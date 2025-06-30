require "test_helper"

class SortableTest < ActiveSupport::TestCase
  class TestController
    include Sortable

    attr_accessor :params

    def initialize(params = {})
      @params = ActionController::Parameters.new(params)
    end
  end

  def setup
    @controller = TestController.new
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)
  end

  test "sort_column returns params sort value" do
    @controller.params = ActionController::Parameters.new(sort: "member")
    assert_equal "member", @controller.sort_column
  end

  test "sort_column returns nil when not present" do
    @controller.params = ActionController::Parameters.new({})
    assert_nil @controller.sort_column
  end

  test "sort_direction validates direction parameter" do
    @controller.params = ActionController::Parameters.new(direction: "desc")
    assert_equal "desc", @controller.sort_direction

    @controller.params = ActionController::Parameters.new(direction: "asc")
    assert_equal "asc", @controller.sort_direction

    @controller.params = ActionController::Parameters.new(direction: "invalid")
    assert_equal "asc", @controller.sort_direction

    @controller.params = ActionController::Parameters.new({})
    assert_equal "asc", @controller.sort_direction
  end

  test "effective_sort_column_for_team_members defaults to github" do
    @controller.params = ActionController::Parameters.new({})
    assert_equal "github", @controller.effective_sort_column_for_team_members

    @controller.params = ActionController::Parameters.new(sort: "member")
    assert_equal "member", @controller.effective_sort_column_for_team_members
  end

  test "apply_team_member_sorting with github sort" do
    @controller.params = ActionController::Parameters.new(sort: "github", direction: "desc")

    # Test with direct TeamMember relation
    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should order by github_login desc
    assert_includes result.to_sql, "github_login"
    assert_includes result.to_sql, "DESC"
  end

  test "apply_team_member_sorting with member sort" do
    @controller.params = ActionController::Parameters.new(sort: "member", direction: "asc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should order by github_login asc (member maps to github_login)
    assert_includes result.to_sql, "github_login"
    assert_includes result.to_sql, "ASC"
  end

  test "apply_team_member_sorting with role sort reverses direction" do
    @controller.params = ActionController::Parameters.new(sort: "role", direction: "asc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should order by maintainer_role desc (reversed from asc)
    assert_includes result.to_sql, "maintainer_role"
    assert_includes result.to_sql, "DESC"
  end

  test "apply_team_member_sorting with access_expires sort" do
    @controller.params = ActionController::Parameters.new(sort: "access_expires", direction: "desc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include access_expires_at ordering
    assert_includes result.to_sql, "access_expires_at"
    assert_includes result.to_sql, "DESC"
    assert_includes result.to_sql, "NULLS LAST"
  end

  test "apply_team_member_sorting with first_seen sort" do
    @controller.params = ActionController::Parameters.new(sort: "first_seen", direction: "asc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include subquery for first seen
    assert_includes result.to_sql, "issue_correlations"
    assert_includes result.to_sql, "MIN(issue_created_at)"
    assert_includes result.to_sql, "ASC"
    assert_includes result.to_sql, "NULLS FIRST"
  end

  test "apply_team_member_sorting with last_seen sort" do
    @controller.params = ActionController::Parameters.new(sort: "last_seen", direction: "desc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include subquery for last seen
    assert_includes result.to_sql, "issue_correlations"
    assert_includes result.to_sql, "MAX(issue_updated_at)"
    assert_includes result.to_sql, "DESC"
    assert_includes result.to_sql, "NULLS LAST"
  end

  test "apply_team_member_sorting with issue sort" do
    @controller.params = ActionController::Parameters.new(sort: "issue", direction: "asc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include subquery for issues
    assert_includes result.to_sql, "issue_correlations"
    assert_includes result.to_sql, "MIN(github_issue_number)"
    assert_includes result.to_sql, "ASC"
    assert_includes result.to_sql, "NULLS FIRST"
  end

  test "apply_team_member_sorting with status sort on team member direct" do
    @controller.params = ActionController::Parameters.new(sort: "status", direction: "asc")

    # Test with direct TeamMember relation (should return unchanged)
    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should not include audit_members ordering for direct team member queries
    assert_equal relation.to_sql, result.to_sql
  end

  test "apply_team_member_sorting with comment sort on team member direct" do
    @controller.params = ActionController::Parameters.new(sort: "comment", direction: "asc")

    # Test with direct TeamMember relation (should return unchanged)
    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should not include audit_members ordering for direct team member queries
    assert_equal relation.to_sql, result.to_sql
  end

  test "apply_team_member_sorting with unknown sort defaults to github" do
    @controller.params = ActionController::Parameters.new(sort: "unknown_column", direction: "asc")

    relation = TeamMember.where(team: @team)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should default to github_login ordering
    assert_includes result.to_sql, "github_login"
    assert_includes result.to_sql, "ASC"
  end

  test "apply_team_member_sorting with audit member relation for status sort" do
    # Create an audit session and member to test joined queries
    audit_session = audit_sessions(:q1_2025_audit)
    audit_member = audit_members(:john_doe)

    @controller.params = ActionController::Parameters.new(sort: "status", direction: "desc")

    # Test with AuditMember relation (joined through audit_members)
    relation = audit_session.audit_members.joins(:team_member)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include audit_members.access_validated ordering
    assert_includes result.to_sql, "audit_members"
    assert_includes result.to_sql, "access_validated"
    assert_includes result.to_sql, "DESC"
  end

  test "apply_team_member_sorting with audit member relation for comment sort" do
    # Create an audit session and member to test joined queries
    audit_session = audit_sessions(:q1_2025_audit)
    audit_member = audit_members(:john_doe)

    @controller.params = ActionController::Parameters.new(sort: "comment", direction: "asc")

    # Test with AuditMember relation (joined through audit_members)
    relation = audit_session.audit_members.joins(:team_member)
    result = @controller.send(:apply_team_member_sorting, relation)

    # Should include audit_members.notes ordering with COALESCE for empty strings
    assert_includes result.to_sql, "audit_members"
    assert_includes result.to_sql, "notes"
    assert_includes result.to_sql, "COALESCE"
    assert_includes result.to_sql, "NULLIF"
    assert_includes result.to_sql, "ASC"
    assert_includes result.to_sql, "NULLS FIRST"
  end
end
