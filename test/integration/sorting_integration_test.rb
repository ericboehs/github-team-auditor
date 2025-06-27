require "test_helper"

class SortingIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :all

  test "teams show page handles member sorting" do
    get team_path(teams(:platform_security), sort: "member", direction: "asc")
    assert_includes [ 200, 302 ], response.status
  end

  test "audits index handles name sorting" do
    get audits_path(sort: "name", direction: "desc")
    assert_includes [ 200, 302 ], response.status
  end

  test "audit show page handles status sorting" do
    get audit_path(audit_sessions(:q1_2025_audit), sort: "status", direction: "asc")
    assert_includes [ 200, 302 ], response.status
  end
end
