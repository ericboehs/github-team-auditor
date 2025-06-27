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
end
