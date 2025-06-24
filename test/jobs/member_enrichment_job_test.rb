require "test_helper"
require "minitest/mock"

class MemberEnrichmentJobTest < ActiveJob::TestCase
  setup do
    @team = teams(:platform_security)
    ENV["GHTA_GITHUB_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("GHTA_GITHUB_TOKEN")
  end

  test "should enrich new members with user details" do
    # Create members without enriched data
    member1 = @team.team_members.create!(
      github_login: "testuser1",
      name: "Basic Name",
      government_employee: false
    )

    member2 = @team.team_members.create!(
      github_login: "testuser2",
      name: nil,
      government_employee: false
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      case username
      when "testuser1"
        {
          name: "Enhanced User 1",
          email: "testuser1@va.gov",
          company: "Department of Veterans Affairs"
        }
      when "testuser2"
        {
          name: "Enhanced User 2",
          email: "testuser2@contractor.com",
          company: "Contractor LLC"
        }
      end
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id, [ "testuser1", "testuser2" ])
    end

    member1.reload
    member2.reload

    assert_equal "Enhanced User 1", member1.name
    assert member1.government_employee

    assert_equal "Enhanced User 2", member2.name
    assert_not member2.government_employee
  end

  test "should handle API errors gracefully" do
    member = @team.team_members.create!(
      github_login: "testuser",
      name: "Original Name",
      government_employee: false
    )

    # Mock API client that raises errors
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      raise StandardError, "API Error"
    end

    Github::ApiClient.stub :new, mock_api_client do
      # Should not raise error, just continue
      assert_nothing_raised do
        MemberEnrichmentJob.perform_now(@team.id, [ "testuser" ])
      end
    end

    member.reload
    # Original data should be unchanged
    assert_equal "Original Name", member.name
    assert_not member.government_employee
  end

  test "should detect government employees correctly" do
    job = MemberEnrichmentJob.new

    # VA email
    user_details = { email: "user@va.gov", company: "Some Company" }
    assert job.send(:detect_government_employee, user_details)

    # Government company
    user_details = { email: "user@contractor.com", company: "Department of Veterans Affairs" }
    assert job.send(:detect_government_employee, user_details)

    # Neither government email nor company
    user_details = { email: "user@contractor.com", company: "Contractor LLC" }
    assert_not job.send(:detect_government_employee, user_details)

    # Nil details
    assert_not job.send(:detect_government_employee, nil)

    # Email present but no government domain
    user_details = { email: "user@contractor.com", company: nil }
    assert_not job.send(:detect_government_employee, user_details)

    # Company present but no government company
    user_details = { email: nil, company: "Contractor LLC" }
    assert_not job.send(:detect_government_employee, user_details)

    # Both email and company nil
    user_details = { email: nil, company: nil }
    assert_not job.send(:detect_government_employee, user_details)

    # Test all government domains
    MemberEnrichmentJob::GOVERNMENT_DOMAINS.each do |domain|
      user_details = { email: "user#{domain}", company: nil }
      assert job.send(:detect_government_employee, user_details), "Should detect #{domain} as government"
    end

    # Test all government companies
    MemberEnrichmentJob::GOVERNMENT_COMPANIES.each do |company|
      user_details = { email: "user@example.com", company: company }
      assert job.send(:detect_government_employee, user_details), "Should detect '#{company}' as government"
    end
  end

  test "should enrich all members when no specific logins provided" do
    # Create members with missing data
    member1 = @team.team_members.create!(
      github_login: "testuser1",
      name: nil,
      government_employee: nil
    )

    member2 = @team.team_members.create!(
      github_login: "testuser2",
      name: "Existing Name",
      government_employee: nil
    )

    # Mock API client
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      {
        name: "API Name for #{username}",
        email: "#{username}@example.com",
        company: "Test Company"
      }
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id) # No specific logins
    end

    member1.reload
    member2.reload

    assert_equal "API Name for testuser1", member1.name
    assert_equal "API Name for testuser2", member2.name
    assert_not member1.government_employee
    assert_not member2.government_employee
  end

  test "should return early when no members to enrich" do
    # Create a member with all data already present
    @team.team_members.create!(
      github_login: "testuser",
      name: "Complete Name",
      government_employee: true
    )

    # Mock API client that should not be called
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      raise "Should not be called"
    end

    Github::ApiClient.stub :new, mock_api_client do
      assert_nothing_raised do
        MemberEnrichmentJob.perform_now(@team.id)
      end
    end
  end

  test "should handle nil user details from API" do
    member = @team.team_members.create!(
      github_login: "testuser",
      name: "Original Name",
      government_employee: false
    )

    # Mock API client that returns nil
    mock_api_client = Object.new
    def mock_api_client.user_details(username)
      nil
    end

    Github::ApiClient.stub :new, mock_api_client do
      MemberEnrichmentJob.perform_now(@team.id, [ "testuser" ])
    end

    member.reload
    # Original data should be unchanged
    assert_equal "Original Name", member.name
    assert_not member.government_employee
  end

  test "should be queued in default queue" do
    assert_equal "default", MemberEnrichmentJob.queue_name
  end
end
