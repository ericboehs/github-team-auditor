# frozen_string_literal: true

require "test_helper"

class LinkButtonComponentTest < ViewComponent::TestCase
  def test_renders_primary_link_button
    component = LinkButtonComponent.new(text: "View Details", url: "/test", variant: :primary)
    render_inline(component)

    assert_selector "a[href='/test']"
    assert_text "View Details"
    assert_selector "a.bg-vads-primary"
  end

  def test_renders_secondary_link_button
    component = LinkButtonComponent.new(text: "Cancel", url: "/cancel", variant: :secondary)
    render_inline(component)

    assert_selector "a[href='/cancel']"
    assert_text "Cancel"
    assert_selector "a.bg-white"
  end

  def test_renders_danger_link_button
    component = LinkButtonComponent.new(text: "Delete", url: "/delete", variant: :danger)
    render_inline(component)

    assert_selector "a[href='/delete']"
    assert_text "Delete"
    assert_selector "a.bg-vads-error"
  end

  def test_renders_warning_link_button
    component = LinkButtonComponent.new(text: "Warning", url: "/warning", variant: :warning)
    render_inline(component)

    assert_selector "a[href='/warning']"
    assert_text "Warning"
    assert_selector "a.bg-vads-warning"
  end

  def test_renders_success_link_button
    component = LinkButtonComponent.new(text: "Success", url: "/success", variant: :success)
    render_inline(component)

    assert_selector "a[href='/success']"
    assert_text "Success"
    assert_selector "a.bg-vads-success"
  end

  def test_renders_link_button_with_flex_by_default
    component = LinkButtonComponent.new(text: "Default Flex", url: "/test")
    render_inline(component)

    assert_selector "a.inline-flex.items-center"
    assert_text "Default Flex"
  end

  def test_renders_link_button_without_flex_when_disabled
    component = LinkButtonComponent.new(text: "No Flex", url: "/test", include_flex: false)
    render_inline(component)

    assert_selector "a"
    refute_selector "a.inline-flex"
    assert_text "No Flex"
  end

  def test_applies_custom_classes
    component = LinkButtonComponent.new(text: "Test", url: "/test", class: "w-full")
    render_inline(component)

    assert_selector "a.w-full"
  end

  def test_renders_link_button_with_unknown_variant
    component = LinkButtonComponent.new(
      text: "Unknown Variant Link",
      url: "/test",
      variant: :unknown
    )
    render_inline(component)

    assert_selector "a", text: "Unknown Variant Link"
    # Should fallback to secondary variant styling
    assert_selector "a.bg-white"
    assert_selector ".rounded-md" # Should have base classes
  end
end
