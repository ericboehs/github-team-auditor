require "test_helper"

class IssueCorrelationTest < ActiveSupport::TestCase
  setup do
    @issue_correlation = issue_correlations(:john_access_request)
  end

  test "should be valid" do
    assert @issue_correlation.valid?
  end

  test "should require github_issue_number" do
    @issue_correlation.github_issue_number = nil
    assert_not @issue_correlation.valid?
    assert_includes @issue_correlation.errors[:github_issue_number], "can't be blank"
  end

  test "should require github_issue_url" do
    @issue_correlation.github_issue_url = nil
    assert_not @issue_correlation.valid?
    assert_includes @issue_correlation.errors[:github_issue_url], "can't be blank"
  end

  test "should validate github_issue_url format" do
    @issue_correlation.github_issue_url = "invalid-url"
    assert_not @issue_correlation.valid?
    assert_includes @issue_correlation.errors[:github_issue_url], "is invalid"
  end

  test "should require title" do
    @issue_correlation.title = nil
    assert_not @issue_correlation.valid?
    assert_includes @issue_correlation.errors[:title], "can't be blank"
  end

  test "open? should return true since we don't track status" do
    assert @issue_correlation.open?
  end

  test "resolved? should return false since we don't track status" do
    assert_not @issue_correlation.resolved?
  end

  test "recent scope should work correctly" do
    recent_issues = IssueCorrelation.recent
    assert_equal IssueCorrelation.all.order(created_at: :desc), recent_issues
  end
end
