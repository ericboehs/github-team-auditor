require "test_helper"

class Dropdown::ButtonComponentTest < ViewComponent::TestCase
  test "renders standard button with default variant" do
    render_inline Dropdown::ButtonComponent.new(text: "Click me")

    assert_selector "button[type='button']", text: "Click me"
    assert_selector "button[data-action='click->dropdown#toggle']"
    assert_selector "button[data-dropdown-target='button']"
    assert_selector "svg" # chevron icon
  end

  test "renders primary variant button" do
    render_inline Dropdown::ButtonComponent.new(text: "Primary", variant: :primary)

    assert_selector "button.bg-vads-primary", text: "Primary"
  end

  test "renders mobile-friendly button when hide_chevron_on_mobile is true" do
    render_inline Dropdown::ButtonComponent.new(text: "Actions", hide_chevron_on_mobile: true)

    # Should have both mobile and desktop buttons
    assert_selector "button.md\\:hidden" # mobile button
    assert_selector "button.\\!hidden.md\\:\\!inline-flex" # desktop button
    assert_text "Actions"
  end

  test "renders button with correct ARIA attributes" do
    render_inline Dropdown::ButtonComponent.new(text: "Options")

    assert_selector "button[aria-expanded='false']"
    assert_selector "button[aria-haspopup='true']"
  end

  test "renders success variant button" do
    render_inline Dropdown::ButtonComponent.new(text: "Success", variant: :success)

    assert_selector "button.bg-vads-success", text: "Success"
  end

  test "renders unknown variant as default" do
    render_inline Dropdown::ButtonComponent.new(text: "Unknown", variant: :unknown)

    assert_selector "button.bg-white", text: "Unknown"
  end
end
