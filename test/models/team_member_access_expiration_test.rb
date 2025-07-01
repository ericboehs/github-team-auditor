require "test_helper"

class TeamMemberAccessExpirationTest < ActiveSupport::TestCase
  def setup
    @organization = organizations(:va)
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)
  end

  test "should extract expiration date from 'expiring MM/DD/YY' format" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "User access expiring 12/25/25")

    @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 12, 25), @team_member.access_expires_at.to_date
  end

  test "should extract expiration date from 'expires MM/DD/YYYY' format" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "User access expires 01/15/2026")

    @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2026, 1, 15), @team_member.access_expires_at.to_date
  end

  test "should extract expiration date from 'access until Month DD, YYYY' format" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Access until January 30, 2025")

    @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 1, 30), @team_member.access_expires_at.to_date
  end

  test "should extract expiration date from YYYY-MM-DD format" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Valid until 2025-03-15")

    @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 3, 15), @team_member.access_expires_at.to_date
  end

  test "should choose latest expiration date when multiple dates found" do
    create_issue_for_member(@team_member, "First access expires 01/15/2025")
    create_issue_for_member(@team_member, "Extended access until 03/20/2025")

    @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 3, 20), @team_member.access_expires_at.to_date
  end

  test "should return nil when no expiration dates found" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "No expiration date mentioned here")

    @team_member.extract_and_update_access_expires_at!

    assert_nil @team_member.access_expires_at
  end

  test "access_expiring_soon? should return true when expires within 30 days" do
    @team_member.update!(access_expires_at: 15.days.from_now)

    assert @team_member.access_expiring_soon?
  end

  test "access_expiring_soon? should return false when expires after 30 days" do
    @team_member.update!(access_expires_at: 45.days.from_now)

    refute @team_member.access_expiring_soon?
  end

  test "access_expired? should return true when date is in the past" do
    @team_member.update!(access_expires_at: 1.day.ago)

    assert @team_member.access_expired?
  end

  test "access_expired? should return false when date is in the future" do
    @team_member.update!(access_expires_at: 1.day.from_now)

    refute @team_member.access_expired?
  end

  test "should handle 2-digit years correctly" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Access expires 12/25/25")

    @team_member.extract_and_update_access_expires_at!

    assert_equal 2025, @team_member.access_expires_at.year
  end

  test "should handle 2-digit years for decades correctly" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Access expires 12/25/75")

    @team_member.extract_and_update_access_expires_at!

    assert_equal 1975, @team_member.access_expires_at.year
  end

  test "should handle malformed dates gracefully" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Access expires 99/99/2025")

    @team_member.extract_and_update_access_expires_at!

    assert_nil @team_member.access_expires_at
  end

  test "should handle empty description" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: "")

    @team_member.extract_and_update_access_expires_at!

    assert_nil @team_member.access_expires_at
  end

  test "should handle nil description" do
    issue = issue_correlations(:john_access_request)
    issue.update!(description: nil)

    @team_member.extract_and_update_access_expires_at!

    assert_nil @team_member.access_expires_at
  end

  test "access_expiring_soon? should return false when no expiration date" do
    @team_member.update!(access_expires_at: nil)

    refute @team_member.access_expiring_soon?
  end

  test "access_expired? should return false when no expiration date" do
    @team_member.update!(access_expires_at: nil)

    refute @team_member.access_expired?
  end

  test "should not update if extracted date is same as current" do
    @team_member.update!(access_expires_at: Date.new(2025, 12, 25))
    original_updated_at = @team_member.updated_at

    issue = issue_correlations(:john_access_request)
    issue.update!(description: "Access expires 12/25/25")

    # Wait a moment to ensure updated_at would change if update! was called
    sleep(0.01)

    result = @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 12, 25), result.to_date
    # updated_at should not have changed since no update was needed
    assert_equal original_updated_at.to_i, @team_member.updated_at.to_i
  end

  private

  def create_issue_for_member(team_member, description)
    IssueCorrelation.create!(
      team_member: team_member,
      github_issue_number: rand(1000..9999),
      github_issue_url: "https://github.com/example/repo/issues/#{rand(1000..9999)}",
      title: "Test Issue",
      description: description,
      status: "open",
      issue_created_at: 1.day.ago,
      issue_updated_at: 1.hour.ago
    )
  end
end
