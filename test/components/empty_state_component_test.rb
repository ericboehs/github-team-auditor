# frozen_string_literal: true

require "test_helper"

class EmptyStateComponentTest < ViewComponent::TestCase
  def test_renders_default_empty_state_with_title_and_message
    component = EmptyStateComponent.new(
      title: "No items found",
      message: "Get started by adding some items."
    )

    render_inline(component)

    assert_selector "div.text-center.py-12"
    assert_selector "h3", text: "No items found"
    assert_selector "p", text: "Get started by adding some items."
  end

  def test_renders_empty_state_with_predefined_icon
    component = EmptyStateComponent.new(
      title: "No teams found",
      message: "Add some teams to get started.",
      icon_name: :teams
    )

    render_inline(component)

    assert_selector "svg.mx-auto.h-12.w-12.text-gray-400"
    assert_selector "h3.mt-2", text: "No teams found"
  end

  def test_renders_empty_state_with_custom_icon_path
    custom_path = "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"

    component = EmptyStateComponent.new(
      title: "Custom icon",
      message: "This uses a custom icon path.",
      icon_path: custom_path
    )

    render_inline(component)

    assert_selector "svg[stroke='currentColor']"
    assert_selector "path[d='#{custom_path}']"
  end

  def test_renders_empty_state_with_action_button
    component = EmptyStateComponent.new(
      title: "No items found",
      message: "Get started by adding some items.",
      action_text: "Add Item",
      action_url: "/items/new",
      action_variant: :primary
    )

    render_inline(component)

    assert_selector "div.mt-6"
    # The LinkButtonComponent will be rendered but we test the component is called
    assert_text "Add Item"
  end

  def test_renders_simple_variant
    component = EmptyStateComponent.new(
      title: "Not used in simple variant",
      message: "No items available",
      variant: :simple
    )

    render_inline(component)

    assert_selector "div.px-4.py-4.sm\\:px-6.text-sm.text-gray-500.dark\\:text-gray-400"
    assert_text "No items available"
    refute_selector "h3"
    refute_selector "svg"
  end

  def test_renders_without_icon_when_not_specified
    component = EmptyStateComponent.new(
      title: "No icon here",
      message: "This empty state has no icon."
    )

    render_inline(component)

    refute_selector "svg"
    assert_selector "h3:not(.mt-2)", text: "No icon here"
  end

  def test_renders_with_additional_options
    component = EmptyStateComponent.new(
      title: "Test",
      message: "Test message",
      id: "custom-empty-state",
      "data-testid": "empty-state"
    )

    render_inline(component)

    assert_selector "div[id='custom-empty-state']"
    assert_selector "div[data-testid='empty-state']"
  end

  def test_renders_bordered_variant
    component = EmptyStateComponent.new(
      title: "No data found",
      message: "This is a bordered empty state.",
      variant: :bordered
    )

    render_inline(component)

    assert_selector "div.text-center.py-12.bg-gray-50.dark\\:bg-gray-800.border.border-gray-200.dark\\:border-gray-700.rounded-lg"
    assert_text "No data found"
    assert_text "This is a bordered empty state."
  end

  def test_predefined_icons_exist
    component = EmptyStateComponent.new(title: "Test", message: "Test")

    icons = component.send(:predefined_icons)

    assert_includes icons.keys, :teams
    assert_includes icons.keys, :audits
    assert_includes icons.keys, :members
    assert icons[:teams].present?
    assert icons[:audits].present?
    assert icons[:members].present?
  end

  def test_icon_svg_path_returns_nil_when_no_icon_specified
    component = EmptyStateComponent.new(
      title: "No Icon",
      message: "This has no icon",
      icon_name: nil
    )

    # This should trigger the missing branch where icon_name.present? is false
    assert_nil component.send(:icon_svg_path)
  end
end
