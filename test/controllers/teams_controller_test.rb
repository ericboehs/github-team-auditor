require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = organizations(:va)
    @team = teams(:platform_security)
  end

  test "should get index" do
    sign_in_as(@user)
    get teams_url
    assert_response :success
    assert_select "h1", I18n.t("teams.index.title")
  end

  test "should get index filtered by organization" do
    sign_in_as(@user)
    get teams_url(organization_id: @organization.id)
    assert_response :success
    assert_select "h1", I18n.t("teams.index.title")
  end

  test "should get show" do
    sign_in_as(@user)
    get team_url(@team)
    assert_response :success
    assert_select "h1", @team.name
  end

  test "should sync team" do
    sign_in_as(@user)

    assert_enqueued_with(job: TeamSyncJob, args: [ @team.id ]) do
      post sync_team_url(@team)
    end

    assert_redirected_to team_url(@team)
    assert_equal I18n.t("flash.teams.sync_started"), flash[:notice]
  end

  test "should get new" do
    sign_in_as(@user)
    get new_team_url
    assert_response :success
    assert_select "h1", "Create New Team"
  end

  test "should get new without default organization" do
    # Delete the default organization to test the branch where find_by returns nil
    default_org = Organization.find_by(github_login: "department-of-veterans-affairs")
    default_org&.destroy

    sign_in_as(@user)
    get new_team_url
    assert_response :success
    assert_select "h1", "Create New Team"
  end

  test "should create team" do
    sign_in_as(@user)
    assert_difference("Team.count") do
      post teams_url, params: { team: { name: "New Team", github_slug: "new-team", organization_id: @organization.id } }
    end

    assert_redirected_to team_url(Team.last)
    assert_equal I18n.t("flash.teams.created"), flash[:notice]
  end

  test "should not create team with invalid params" do
    sign_in_as(@user)
    assert_no_difference("Team.count") do
      post teams_url, params: { team: { name: "", github_slug: "", organization_id: nil } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    sign_in_as(@user)
    get edit_team_url(@team)
    assert_response :success
    assert_select "h1", "Edit Team"
  end

  test "should update team" do
    sign_in_as(@user)
    patch team_url(@team), params: { team: { name: "Updated Team Name" } }
    assert_redirected_to team_url(@team)
    assert_equal I18n.t("flash.teams.updated"), flash[:notice]
  end

  test "should not update team with invalid params" do
    sign_in_as(@user)
    patch team_url(@team), params: { team: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "should destroy team" do
    sign_in_as(@user)
    assert_difference("Team.count", -1) do
      delete team_url(@team)
    end

    assert_redirected_to teams_url
    assert_equal I18n.t("flash.teams.deleted"), flash[:notice]
  end

  test "should redirect to login when not authenticated" do
    get teams_url
    assert_redirected_to new_session_url
  end

  test "should find issue correlations" do
    sign_in_as(@user)
    assert_enqueued_jobs 1, only: IssueCorrelationFinderJob do
      post find_issue_correlations_team_path(@team)
    end

    assert_redirected_to team_path(@team)
    assert_equal I18n.t("flash.teams.issue_correlation_started"), flash[:notice]
  end

  test "should poll for updates" do
    sign_in_as(@user)
    get poll_team_path(@team), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end
end
