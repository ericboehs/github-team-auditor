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

  test "access_expiring_soon? returns true when expires within 30 days" do
    @team_member.access_expires_at = 15.days.from_now
    assert @team_member.access_expiring_soon?

    @team_member.access_expires_at = 45.days.from_now
    refute @team_member.access_expiring_soon?

    @team_member.access_expires_at = nil
    refute @team_member.access_expiring_soon?
  end

  test "access_expired? returns true when access has expired" do
    @team_member.access_expires_at = 1.day.ago
    assert @team_member.access_expired?

    @team_member.access_expires_at = 1.day.from_now
    refute @team_member.access_expired?

    @team_member.access_expires_at = nil
    refute @team_member.access_expired?
  end

  test "extract_relative_expiration_dates with approved for X months pattern" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Test "approved for 6 months" pattern
    text = "I've approved you for 6 months of access"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 6.months
    assert_equal [ expected_date ], dates

    # Test "granted 12 months access" pattern
    text = "We have granted 12 months access"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 12.months
    assert_equal [ expected_date ], dates

    # Test "given you 3 months approval" pattern
    text = "We have given you 3 months approval"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 3.months
    assert_equal [ expected_date ], dates
  end

  test "extract_relative_expiration_dates with X month access pattern" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Test "6 month approval" pattern
    text = "This is a 6 month approval"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 6.months
    assert_equal [ expected_date ], dates

    # Test "12-month access" pattern
    text = "12-month access granted"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 12.months
    assert_equal [ expected_date ], dates
  end

  test "extract_relative_expiration_dates with access for X months pattern" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Test "access for 6 months" pattern
    text = "You have access for 6 months"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 6.months
    assert_equal [ expected_date ], dates

    # Test "valid for 9 months" pattern
    text = "This access is valid for 9 months"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    expected_date = reference_date + 9.months
    assert_equal [ expected_date ], dates
  end

  test "extract_relative_expiration_dates handles edge cases" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Empty text
    dates = @team_member.send(:extract_relative_expiration_dates, "", reference_date)
    assert_equal [], dates

    # No reference date
    text = "approved for 6 months"
    dates = @team_member.send(:extract_relative_expiration_dates, text, nil)
    assert_equal [], dates

    # Invalid month count (too high)
    text = "approved for 36 months"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    assert_equal [], dates

    # Invalid month count (zero)
    text = "approved for 0 months"
    dates = @team_member.send(:extract_relative_expiration_dates, text, reference_date)
    assert_equal [], dates
  end

  test "extract_expiration_dates_from_comments prefers absolute dates over relative" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Text with both absolute and relative dates
    text = "expires 12/31/2024 and I've approved you for 6 months"
    dates = @team_member.send(:extract_expiration_dates_from_comments, text, reference_date)

    # Should return absolute date and not process relative since absolute was found
    assert_includes dates, Date.new(2024, 12, 31)
    # Should not include the relative date since absolute dates were found
    refute_includes dates, reference_date + 6.months
  end

  test "extract_expiration_dates_from_comments falls back to relative when no absolute dates" do
    @team_member.save!
    reference_date = Date.new(2024, 10, 9)

    # Text with only relative dates
    text = "I've approved you for 6 months of access"
    dates = @team_member.send(:extract_expiration_dates_from_comments, text, reference_date)

    expected_date = reference_date + 6.months
    assert_equal [ expected_date ], dates
  end

  test "extract_and_update_access_expires_at! uses relative dates from comments" do
    @team_member.save!

    # Create issue with comment containing relative date from a maintainer
    @team_member.issue_correlations.create!(
      github_issue_number: 123,
      github_issue_url: "https://github.com/test/repo/issues/123",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      comments: "I've approved you for 6 months of access",
      comment_authors: [ "john_doe" ]  # john_doe is a maintainer in fixtures
    )

    result = @team_member.extract_and_update_access_expires_at!
    expected_date = Date.new(2024, 10, 9) + 6.months

    assert_equal expected_date, result
    assert_equal expected_date, @team_member.reload.access_expires_at.to_date
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check only extracts from maintainers" do
    @team_member.save!

    # Create issue with comments from both maintainer and non-maintainer
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 124,
      github_issue_url: "https://github.com/test/repo/issues/124",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      comments: "I need access until 12/31/2024\n\n---\n\nI've approved you for 6 months of access",
      comment_authors: [ "jane_smith", "john_doe" ]  # jane_smith is not maintainer, john_doe is
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should only extract from john_doe's comment (the maintainer)
    expected_date = Date.new(2024, 10, 9) + 6.months
    assert_equal [ expected_date ], dates
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check uses fallback for non-maintainer comments" do
    @team_member.save!

    # Create issue with comment only from non-maintainer (not issue author)
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 125,
      github_issue_url: "https://github.com/test/repo/issues/125",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      issue_author: "requester_user",  # Different from comment author
      comments: "I've approved you for 12 months access",
      comment_authors: [ "jane_smith" ]  # jane_smith is not a maintainer but not issue author
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should use fallback and extract from jane_smith's comment since she's not the issue author
    expected_date = Date.new(2024, 10, 9) + 12.months
    assert_equal [ expected_date ], dates
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check handles missing comment_authors" do
    @team_member.save!

    # Create issue without comment_authors
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 126,
      github_issue_url: "https://github.com/test/repo/issues/126",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      comments: "I've approved you for 6 months of access",
      comment_authors: nil
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should return empty array when comment_authors is missing
    assert_equal [], dates
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check excludes issue author from fallback" do
    @team_member.save!

    # Create issue where the issue author also commented
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 127,
      github_issue_url: "https://github.com/test/repo/issues/127",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      issue_author: "requester_user",
      comments: "I need access for 6 months\n\n---\n\nI've approved you for 12 months access",
      comment_authors: [ "requester_user", "jane_smith" ]  # First comment from issue author, second from someone else
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should only extract from jane_smith's comment, ignoring the issue author's comment
    expected_date = Date.new(2024, 10, 9) + 12.months
    assert_equal [ expected_date ], dates
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check prefers later date when historical maintainer grants longer access" do
    @team_member.save!

    # Create issue where historical maintainer grants longer access than current maintainer
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 128,
      github_issue_url: "https://github.com/test/repo/issues/128",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      issue_author: "requester_user",
      comments: "Approved for 6 months access\n\n---\n\nActually, extending to 12 months access",
      comment_authors: [ "john_doe", "jane_smith" ]  # john_doe is maintainer, jane_smith is not but grants longer access
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should use the later date (12 months) even though it's from non-current maintainer
    expected_date = Date.new(2024, 10, 9) + 12.months
    assert_equal [ expected_date ], dates
  end

  test "extract_expiration_dates_from_comments_with_maintainer_check prefers maintainer when maintainer date is later" do
    @team_member.save!

    # Create issue where maintainer grants longer access than historical maintainer
    issue = @team_member.issue_correlations.create!(
      github_issue_number: 129,
      github_issue_url: "https://github.com/test/repo/issues/129",
      title: "Access request",
      status: "open",
      issue_created_at: Date.new(2024, 10, 9),
      issue_updated_at: Date.new(2024, 10, 9),
      issue_author: "requester_user",
      comments: "Approved for 6 months access\n\n---\n\nExtending to 12 months access",
      comment_authors: [ "jane_smith", "john_doe" ]  # jane_smith is not maintainer, john_doe is
    )

    dates = @team_member.send(:extract_expiration_dates_from_comments_with_maintainer_check, issue)

    # Should use maintainer's date (12 months) since it's later
    expected_date = Date.new(2024, 10, 9) + 12.months
    assert_equal [ expected_date ], dates
  end

  test "extract_expiration_dates_from_text handles edge cases" do
    @team_member.save!

    # Test line 104: when match_pos is nil (text.index returns nil)
    # This should never happen in normal flow but tests the nil guard
    text_with_weird_match = "Access until 12/31/24"

    # Stub text.index to return nil for testing the guard
    text_with_weird_match.define_singleton_method(:index) { |_| nil }

    dates = @team_member.send(:extract_expiration_dates_from_text, text_with_weird_match)

    # Should handle nil gracefully and not crash
    assert_instance_of Array, dates
  end

  test "extract_expiration_dates_from_comments handles blank comments" do
    @team_member.save!

    # Test line 119: blank comments_text
    dates = @team_member.send(:extract_expiration_dates_from_comments, "", Date.current)
    assert_equal [], dates

    dates = @team_member.send(:extract_expiration_dates_from_comments, nil, Date.current)
    assert_equal [], dates
  end

  test "extract_expiration_dates_from_comments uses relative when no absolute dates" do
    @team_member.save!

    # Test line 127: when dates.empty? && reference_date
    comments_without_absolute_dates = "You have been approved for 6 months access"
    reference_date = Date.new(2024, 1, 1)

    dates = @team_member.send(:extract_expiration_dates_from_comments, comments_without_absolute_dates, reference_date)

    # Should find the relative date (6 months from reference)
    expected_date = reference_date + 6.months
    assert_equal [ expected_date ], dates
  end

  test "parse_date_string handles various formats" do
    @team_member.save!

    # Test MM/DD/YY format
    date = @team_member.send(:parse_date_string, "12/31/24")
    assert_equal Date.new(2024, 12, 31), date

    # Test MM/DD/YYYY format
    date = @team_member.send(:parse_date_string, "01/15/2025")
    assert_equal Date.new(2025, 1, 15), date

    # Test YYYY-MM-DD format
    date = @team_member.send(:parse_date_string, "2025-03-15")
    assert_equal Date.new(2025, 3, 15), date

    # Test "Month DD, YYYY" format
    date = @team_member.send(:parse_date_string, "December 31, 2024")
    assert_equal Date.new(2024, 12, 31), date

    # Test invalid date string
    date = @team_member.send(:parse_date_string, "invalid date")
    assert_nil date

    # Test blank string
    date = @team_member.send(:parse_date_string, "")
    assert_nil date

    # Test nil
    date = @team_member.send(:parse_date_string, nil)
    assert_nil date
  end

  test "extract_expiration_dates_from_text finds dates in context" do
    @team_member.save!

    # Test date with context
    text = "Your access expires 12/31/2024 so please renew"
    dates = @team_member.send(:extract_expiration_dates_from_text, text)
    assert_includes dates, Date.new(2024, 12, 31)

    # Test date without context (should not be included)
    text = "Meeting on 12/31/2024 about something else"
    dates = @team_member.send(:extract_expiration_dates_from_text, text)
    assert_empty dates

    # Test blank text
    dates = @team_member.send(:extract_expiration_dates_from_text, "")
    assert_empty dates
  end

  test "extract_latest_expiration_date with no issue correlations" do
    @team_member.save!

    # Should return nil when no issue correlations exist
    result = @team_member.send(:extract_latest_expiration_date)
    assert_nil result
  end

  test "extract_and_update_access_expires_at! does not update when date unchanged" do
    @team_member.save!
    @team_member.update!(access_expires_at: Date.new(2025, 6, 1))

    # Mock extract_latest_expiration_date to return same date
    @team_member.define_singleton_method(:extract_latest_expiration_date) { Date.new(2025, 6, 1) }

    # Should not trigger an update since date is the same
    original_updated_at = @team_member.updated_at
    sleep 0.001 # Ensure time difference if update occurred

    result = @team_member.extract_and_update_access_expires_at!

    assert_equal Date.new(2025, 6, 1), result
    assert_equal original_updated_at.to_i, @team_member.reload.updated_at.to_i
  end
end
