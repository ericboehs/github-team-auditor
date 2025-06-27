# Start SimpleCov before loading Rails
require "simplecov"

SimpleCov.start "rails" do
  # Silence verbose coverage output during test runs
  SimpleCov.print_error_status = false

  # Enable coverage for branches (Ruby 2.5+) - must come before minimum_coverage
  enable_coverage :branch

  # Set minimum coverage percentage
  minimum_coverage line: 95, branch: 90

  # Set coverage percentage precision
  minimum_coverage_by_file 90

  # Add filters for files/directories to exclude from coverage
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/bin/"
  add_filter "/test/"
  add_filter "app/channels/application_cable/connection.rb"
  add_filter "app/jobs/application_job.rb"

  # Group coverage results for better organization
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Helpers", "app/helpers"
  add_group "Mailers", "app/mailers"
  add_group "Channels", "app/channels"
  add_group "Libraries", "lib/"

  # Use Rails' default profile with some modifications
  track_files "{app,lib}/**/*.rb"

  # Set up formatters
  formatter SimpleCov::Formatter::HTMLFormatter

  # Refuse to run tests if coverage drops below threshold
  refuse_coverage_drop :line, :branch

  # Maximum coverage drop allowed
  maximum_coverage_drop 5
end

ENV["RAILS_ENV"] ||= "test"
# Set a dummy GitHub token for testing
ENV["GHTA_GITHUB_TOKEN"] ||= "ghp_dummy_token_for_testing_only"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Configure SimpleCov for parallel test execution
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Shared authentication helper for controller tests
    def sign_in_as(user)
      post session_url, params: { email_address: user.email_address, password: "password123" }
    end
  end
end
