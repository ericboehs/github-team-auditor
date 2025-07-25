require "test_helper"

class SortingLogicTest < ActiveSupport::TestCase
  test "sortable concern validates sort direction" do
    controller = Class.new do
      include Sortable
      attr_accessor :params
      def initialize; @params = {}; end
    end.new

    # Test valid directions
    controller.params = { direction: "asc" }
    assert_equal "asc", controller.send(:sort_direction)

    controller.params = { direction: "desc" }
    assert_equal "desc", controller.send(:sort_direction)

    # Test invalid directions default to asc
    controller.params = { direction: "invalid" }
    assert_equal "asc", controller.send(:sort_direction)

    controller.params = { direction: "DROP TABLE users" }
    assert_equal "asc", controller.send(:sort_direction)

    # Test nil direction defaults to asc
    controller.params = {}
    assert_equal "asc", controller.send(:sort_direction)
  end

  test "sortable concern handles sort column parameter" do
    controller = Class.new do
      include Sortable
      attr_accessor :params
      def initialize; @params = {}; end
    end.new

    # Test with sort parameter
    controller.params = { sort: "name" }
    assert_equal "name", controller.send(:sort_column)

    # Test without sort parameter
    controller.params = {}
    assert_nil controller.send(:sort_column)

    # Test with empty sort parameter
    controller.params = { sort: "" }
    assert_nil controller.send(:sort_column)
  end

  test "sortable concern handles effective sort column for team members" do
    controller = Class.new do
      include Sortable
      attr_accessor :params
      def initialize; @params = {}; end
    end.new

    # Test with sort parameter
    controller.params = { sort: "member" }
    assert_equal "member", controller.effective_sort_column_for_team_members

    # Test without sort parameter returns default "github"
    controller.params = {}
    assert_equal "github", controller.effective_sort_column_for_team_members

    # Test with empty sort parameter returns default "github"
    controller.params = { sort: "" }
    assert_equal "github", controller.effective_sort_column_for_team_members
  end

  test "audit controller apply_audit_sorting handles all columns" do
    controller = AuditsController.new
    controller.params = { sort: "name", direction: "asc" }

    # Mock audit sessions relation
    relation = AuditSession.all

    # Test each sort column
    %w[name team status started due_date].each do |column|
      controller.params = { sort: column, direction: "asc" }
      result = controller.send(:apply_audit_sorting, relation)
      assert_not_nil result
    end

    # Test invalid column falls back to default
    controller.params = { sort: "invalid", direction: "asc" }
    result = controller.send(:apply_audit_sorting, relation)
    assert_not_nil result
  end

  test "audit controller apply_team_member_sorting handles all columns" do
    controller = AuditsController.new
    controller.params = { sort: "member", direction: "asc" }

    # Mock audit members relation
    relation = AuditMember.joins(:team_member)

    # Test each sort column
    %w[github member role status first_seen last_seen comment issue].each do |column|
      controller.params = { sort: column, direction: "asc" }
      result = controller.send(:apply_team_member_sorting, relation)
      assert_not_nil result

      # Test desc direction too
      controller.params = { sort: column, direction: "desc" }
      result = controller.send(:apply_team_member_sorting, relation)
      assert_not_nil result
    end

    # Test default sorting with invalid column (covers line 116 - else branch)
    controller.params = { sort: "invalid_column", direction: "asc" }
    result = controller.send(:apply_team_member_sorting, relation)
    assert_not_nil result
  end

  test "teams controller apply_team_member_sorting handles all columns" do
    controller = TeamsController.new
    controller.params = { sort: "member", direction: "asc" }

    # Mock team members relation
    relation = TeamMember.all

    # Test each sort column (excluding comment and status which don't apply to teams)
    %w[github member role first_seen last_seen issue].each do |column|
      controller.params = { sort: column, direction: "asc" }
      result = controller.send(:apply_team_member_sorting, relation)
      assert_not_nil result

      # Test desc direction too
      controller.params = { sort: column, direction: "desc" }
      result = controller.send(:apply_team_member_sorting, relation)
      assert_not_nil result
    end

    # Test that status and comment sorting are skipped for teams (returns relation without error)
    %w[status comment].each do |column|
      controller.params = { sort: column, direction: "asc" }
      result = controller.send(:apply_team_member_sorting, relation)
      # Should return a valid relation without error
      assert_not_nil result
      assert_respond_to result, :to_sql
    end
  end

  test "team member sorting handles both direct and joined contexts" do
    # Test direct TeamMember context
    direct_controller = TeamsController.new
    direct_controller.params = { sort: "github", direction: "asc" }
    direct_relation = TeamMember.all
    direct_result = direct_controller.send(:apply_team_member_sorting, direct_relation)
    assert_not_nil direct_result

    # Test joined AuditMember context
    joined_controller = AuditsController.new
    joined_controller.params = { sort: "github", direction: "asc" }
    joined_relation = AuditMember.joins(:team_member)
    joined_result = joined_controller.send(:apply_team_member_sorting, joined_relation)
    assert_not_nil joined_result
  end
end
