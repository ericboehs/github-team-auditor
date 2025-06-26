require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def setup
    @resolved_issue = IssueCorrelation.new(status: "resolved")
    @open_issue = IssueCorrelation.new(status: "open")
  end

  test "issue_status_icon returns purple check circle for resolved issues" do
    result = issue_status_icon(@resolved_issue)

    assert_includes result, 'class="h-4 w-4 text-purple-600"'
    assert_includes result, 'viewBox="0 0 24 24"'
    assert_includes result, 'aria-hidden="true"'
    assert_includes result, 'd="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"'
  end

  test "issue_status_icon returns green exclamation circle for open issues" do
    result = issue_status_icon(@open_issue)

    assert_includes result, 'class="h-4 w-4 text-green-600"'
    assert_includes result, 'viewBox="0 0 24 24"'
    assert_includes result, 'aria-hidden="true"'
    assert_includes result, 'd="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"'
  end

  test "issue_status_icon accepts custom css classes" do
    result = issue_status_icon(@resolved_issue, "h-6 w-6 custom-class")

    assert_includes result, 'class="h-6 w-6 custom-class text-purple-600"'
  end
end
