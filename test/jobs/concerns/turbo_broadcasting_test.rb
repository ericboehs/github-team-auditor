require "test_helper"

class TurboBroadcastingTest < ActiveSupport::TestCase
  # Test class that includes the concern
  class TestJob
    include TurboBroadcasting
  end

  setup do
    @job = TestJob.new
    @team = teams(:platform_security)
    @organization = @team.organization
  end

  test "translate_error_message returns correct message for configuration error" do
    config_error = Github::ApiClient::ConfigurationError.new("Config error")
    assert_equal I18n.t("jobs.shared.errors.configuration"),
                @job.send(:translate_error_message, config_error)
  end

  test "translate_error_message returns correct message for network errors" do
    econnrefused_error = Errno::ECONNREFUSED.new
    assert_equal I18n.t("jobs.shared.errors.network"),
                @job.send(:translate_error_message, econnrefused_error)
  end

  test "translate_error_message returns unexpected message for unknown errors" do
    standard_error = StandardError.new
    assert_equal I18n.t("jobs.shared.errors.unexpected"),
                @job.send(:translate_error_message, standard_error)
  end

  test "concern is properly included and methods are accessible" do
    assert @job.private_methods.include?(:broadcast_job_started)
    assert @job.private_methods.include?(:broadcast_job_completed)
    assert @job.private_methods.include?(:broadcast_job_error)
    assert @job.private_methods.include?(:translate_error_message)
  end

  test "broadcast methods are accessible" do
    # Test that all broadcast methods are private and accessible
    assert @job.private_methods.include?(:broadcast_flash_message)
    assert @job.private_methods.include?(:broadcast_live_announcement)
    assert @job.private_methods.include?(:broadcast_status_banner)
    assert @job.private_methods.include?(:broadcast_clear_flash_messages)
  end

  test "translate_error_message handles network errors correctly" do
    # Test with Errno::ECONNREFUSED which is already tested but this covers more branch coverage
    econnrefused_error = Errno::ECONNREFUSED.new
    assert_equal I18n.t("jobs.shared.errors.network"),
                @job.send(:translate_error_message, econnrefused_error)

    # Test with a different network error class
    # Since Net::TimeoutError might not be available, let's create a mock
    mock_error = Object.new
    mock_error.define_singleton_method(:class) do
      mock_class = Object.new
      mock_class.define_singleton_method(:name) { "Net::TimeoutError" }
      mock_class
    end

    assert_equal I18n.t("jobs.shared.errors.network"),
                @job.send(:translate_error_message, mock_error)
  end
end
