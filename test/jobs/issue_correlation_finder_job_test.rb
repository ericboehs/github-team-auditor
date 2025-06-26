require "test_helper"

class IssueCorrelationFinderJobTest < ActiveJob::TestCase
  def setup
    @organization = organizations(:va)
    @team = teams(:platform_security)
    @team_member = team_members(:john_doe_team_member)
  end

  test "job is enqueued with correct arguments" do
    assert_enqueued_with(job: IssueCorrelationFinderJob, args: [ @team.id ]) do
      IssueCorrelationFinderJob.perform_later(@team.id)
    end
  end

  test "job is enqueued with search options" do
    assert_enqueued_with(
      job: IssueCorrelationFinderJob,
      args: [ @team.id, { search_terms: "custom", exclusion_terms: "test", repository: "custom/repo" } ]
    ) do
      IssueCorrelationFinderJob.perform_later(@team.id, search_terms: "custom", exclusion_terms: "test", repository: "custom/repo")
    end
  end

  test "job handles team not found error" do
    assert_raises(ActiveRecord::RecordNotFound) do
      IssueCorrelationFinderJob.new.perform(999999) # Non-existent team ID
    end
  end

  test "job creates correlation service with correct parameters" do
    job = IssueCorrelationFinderJob.new

    # Set up the job state as if setup_job was called
    job.instance_variable_set(:@team, @team)
    job.instance_variable_set(:@organization, @organization)
    job.instance_variable_set(:@search_terms, "test terms")
    job.instance_variable_set(:@exclusion_terms, "exclude terms")
    job.instance_variable_set(:@repository, "test/repo")

    # Create a stub API client
    api_client = Object.new
    def api_client.search_issues(query, repository:); []; end
    job.instance_variable_set(:@api_client, api_client)

    # Define a minimal find_correlations_for_team method
    def job.find_correlations_for_team; end

    job.send(:process_correlations)

    # Verify the service was created
    service = job.instance_variable_get(:@correlation_service)
    assert_not_nil service
    assert_instance_of IssueCorrelationService, service
    assert_equal @team, service.team
    assert_equal "test terms", service.search_terms
  end

  test "job uses team effective configuration methods" do
    # Test that the job calls the right methods on the team
    assert_respond_to @team, :effective_search_terms
    assert_respond_to @team, :effective_exclusion_terms
    assert_respond_to @team, :effective_search_repository

    # Test default values
    assert_equal "access", @team.effective_search_terms
    assert_equal "", @team.effective_exclusion_terms
    assert_equal "#{@organization.github_login}/va.gov-team", @team.effective_search_repository
  end
end
