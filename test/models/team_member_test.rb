require "test_helper"

class TeamMemberTest < ActiveSupport::TestCase
  setup do
    @team = teams(:platform_security)
    @team_member = TeamMember.new(
      team: @team,
      github_login: "testuser",
      name: "Test User"
    )
  end

  test "includes GithubUrlable concern" do
    assert @team_member.respond_to?(:github_url)
    assert @team_member.respond_to?(:display_name)
  end

  test "validates github_login uniqueness within team scope" do
    existing_member = TeamMember.create!(
      team: @team,
      github_login: "testuser",
      name: "Existing User"
    )

    duplicate_member = TeamMember.new(
      team: @team,
      github_login: "testuser",
      name: "Duplicate User"
    )

    refute duplicate_member.valid?
    assert_includes duplicate_member.errors[:github_login], "has already been taken"
  end

  test "allows same github_login in different teams" do
    other_team = Team.create!(
      organization: @team.organization,
      name: "Other Team",
      github_slug: "other-team"
    )

    TeamMember.create!(
      team: @team,
      github_login: "testuser",
      name: "User in Team 1"
    )

    duplicate_in_other_team = TeamMember.new(
      team: other_team,
      github_login: "testuser",
      name: "User in Team 2"
    )

    assert duplicate_in_other_team.valid?
  end

  test "current scope returns active members" do
    active_member = TeamMember.create!(
      team: @team,
      github_login: "active_user",
      name: "Active User",
      active: true
    )

    inactive_member = TeamMember.create!(
      team: @team,
      github_login: "inactive_user",
      name: "Inactive User",
      active: false
    )

    current_members = TeamMember.current
    assert_includes current_members, active_member
    refute_includes current_members, inactive_member
  end

  test "github_url and display_name work through concern" do
    @team_member.github_login = "testuser"
    @team_member.name = "Test User"

    assert_equal "https://github.com/testuser", @team_member.github_url
    assert_equal "Test User", @team_member.display_name

    @team_member.name = nil
    assert_equal "testuser", @team_member.display_name
  end

  test "should calculate first_seen_at from earliest issue creation date" do
    @team_member.save!

    # Create issue correlations with different dates
    @team_member.issue_correlations.create!(
      github_issue_number: 111,
      github_issue_url: "https://github.com/test/repo/issues/111",
      title: "Early issue",
      status: "open",
      issue_created_at: 3.days.ago,
      issue_updated_at: 1.day.ago
    )
    @team_member.issue_correlations.create!(
      github_issue_number: 222,
      github_issue_url: "https://github.com/test/repo/issues/222",
      title: "Later issue",
      status: "open",
      issue_created_at: 1.day.ago,
      issue_updated_at: 1.hour.ago
    )

    assert_equal 3.days.ago.to_date, @team_member.first_seen_at.to_date
  end

  test "should calculate last_seen_at from latest issue update date" do
    @team_member.save!

    # Create issue correlations with different dates
    @team_member.issue_correlations.create!(
      github_issue_number: 111,
      github_issue_url: "https://github.com/test/repo/issues/111",
      title: "Old issue",
      status: "open",
      issue_created_at: 3.days.ago,
      issue_updated_at: 2.days.ago
    )
    @team_member.issue_correlations.create!(
      github_issue_number: 222,
      github_issue_url: "https://github.com/test/repo/issues/222",
      title: "Updated issue",
      status: "open",
      issue_created_at: 2.days.ago,
      issue_updated_at: 1.hour.ago
    )

    assert_equal 1.hour.ago.to_i, @team_member.last_seen_at.to_i, delta: 10
  end

  test "should return nil for first_seen_at when no issue correlations" do
    @team_member.save!
    assert_nil @team_member.first_seen_at
  end

  test "should return nil for last_seen_at when no issue correlations" do
    @team_member.save!
    assert_nil @team_member.last_seen_at
  end
end
