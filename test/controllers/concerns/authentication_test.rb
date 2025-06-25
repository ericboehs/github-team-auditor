require "test_helper"

class DummyController < ApplicationController
  include Authentication

  # Make private methods accessible for testing
  def test_authenticated?
    authenticated?
  end

  def test_resume_session
    resume_session
  end
end

class AuthenticationConcernTest < ActionController::TestCase
  tests DummyController

  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end

  test "authenticated? returns session when session exists" do
    session = @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")

    # Use the cookies helper which creates a proper signed cookie jar
    @controller.send(:cookies).signed[:session_id] = session.id

    result = @controller.test_authenticated?
    assert_not_nil result
    assert_equal session.id, result.id
  end

  test "authenticated? returns nil when no session" do
    assert_nil @controller.test_authenticated?
  end

  test "authenticated? returns nil when session id invalid" do
    @controller.send(:cookies).signed[:session_id] = 99999
    assert_nil @controller.test_authenticated?
  end
end
