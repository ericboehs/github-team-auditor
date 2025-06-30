# frozen_string_literal: true

require "test_helper"

class HelpModalComponentTest < ViewComponent::TestCase
  def test_renders_keyboard_shortcuts_modal
    component = HelpModalComponent.new
    render_inline(component)

    assert_selector "h3", text: I18n.t("keyboard_shortcuts.title"), visible: false
    assert_selector "h4", text: I18n.t("keyboard_shortcuts.sections.navigation.title"), visible: false
    assert_selector "h4", text: I18n.t("keyboard_shortcuts.sections.emacs_style.title"), visible: false
    assert_selector "h4", text: I18n.t("keyboard_shortcuts.sections.actions.title"), visible: false
    assert_selector "h4", text: I18n.t("keyboard_shortcuts.sections.help.title"), visible: false
    assert_selector "button", text: I18n.t("buttons.close"), visible: false
  end

  def test_renders_keyboard_shortcuts_content
    component = HelpModalComponent.new
    render_inline(component)

    # Check that key shortcuts descriptions are translated (modal is hidden by default)
    assert_selector "span", text: I18n.t("keyboard_shortcuts.sections.navigation.move_left_right"), visible: false
    assert_selector "span", text: I18n.t("keyboard_shortcuts.sections.actions.edit_comment"), visible: false
    assert_selector "span", text: I18n.t("keyboard_shortcuts.sections.help.show_hide_help"), visible: false
  end

  def test_renders_keyboard_bindings
    component = HelpModalComponent.new
    render_inline(component)

    # Check that keyboard bindings are displayed (modal is hidden by default)
    assert_selector "kbd", text: "Ctrl", visible: false
    assert_selector "kbd", text: "Enter", visible: false
    assert_selector "kbd", text: "Esc", visible: false
    assert_selector "kbd", text: "H/L", visible: false
    assert_selector "kbd", text: "J/K", visible: false
  end
end
