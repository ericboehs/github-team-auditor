require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Silence Puma server output during system tests
  Capybara.server = :puma, { Silent: true }

  private

  def sign_in_as(user)
    visit new_session_url

    # Clear and fill the email field
    email_field = find("input[name='email_address']")
    email_field.click
    email_field.fill_in(with: user.email_address)

    # Fill password field
    fill_in "password", with: "password123"

    click_on I18n.t("auth.sign_in.submit_button")
  end
end
