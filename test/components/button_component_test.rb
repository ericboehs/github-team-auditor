# frozen_string_literal: true

require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  def test_renders_primary_button
    component = ButtonComponent.new(text: "Sign In", type: :submit, variant: :primary)
    render_inline(component)

    assert_selector "button[type='submit']"
    assert_text "Sign In"
    assert_selector "button.bg-vads-primary"
  end

  def test_renders_secondary_button
    component = ButtonComponent.new(text: "Cancel", variant: :secondary)
    render_inline(component)

    assert_selector "button"
    assert_text "Cancel"
    assert_selector "button.bg-white"
  end

  def test_applies_custom_classes
    component = ButtonComponent.new(text: "Test", class: "w-full")
    render_inline(component)

    assert_selector "button.w-full"
  end

  def test_renders_danger_button
    component = ButtonComponent.new(text: "Delete", variant: :danger)
    render_inline(component)

    assert_selector "button"
    assert_text "Delete"
    assert_selector "button.bg-vads-error"
  end

  def test_renders_warning_button
    component = ButtonComponent.new(text: "Warning", variant: :warning)
    render_inline(component)

    assert_selector "button"
    assert_text "Warning"
    assert_selector "button.bg-vads-warning"
  end

  def test_renders_success_button
    component = ButtonComponent.new(text: "Success", variant: :success)
    render_inline(component)

    assert_selector "button"
    assert_text "Success"
    assert_selector "button.bg-vads-success"
  end

  def test_renders_button_with_flex
    component = ButtonComponent.new(text: "With Flex", include_flex: true)
    render_inline(component)

    assert_selector "button.inline-flex.items-center"
    assert_text "With Flex"
  end

  def test_renders_button_without_flex
    component = ButtonComponent.new(text: "Without Flex", include_flex: false)
    render_inline(component)

    assert_selector "button"
    refute_selector "button.inline-flex"
    assert_text "Without Flex"
  end

  def test_renders_button_with_unknown_variant
    component = ButtonComponent.new(
      text: "Unknown Variant Button",
      variant: :unknown
    )
    render_inline(component)

    assert_selector "button", text: "Unknown Variant Button"
    # Should fallback to secondary variant styling
    assert_selector "button.bg-white"
    assert_selector ".rounded-md" # Should have base classes
  end
end
