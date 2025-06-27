# frozen_string_literal: true

require "test_helper"

class StatsCardComponentTest < ViewComponent::TestCase
  def test_renders_stats_card_with_default_styling
    component = StatsCardComponent.new(
      title: "Total Teams",
      value: 42,
      icon_path: "M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
    )
    render_inline(component)

    assert_selector "div.bg-white.dark\\:bg-gray-800"
    assert_text "Total Teams"
    assert_text "42"
    assert_selector "svg"
  end

  def test_renders_stats_card_with_custom_colors
    component = StatsCardComponent.new(
      title: "Active Members",
      value: 15,
      icon_path: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z",
      icon_color: "text-purple-600 dark:text-purple-400"
    )
    render_inline(component)

    assert_selector "svg.text-purple-600"
    assert_text "Active Members"
    assert_text "15"
  end

  def test_applies_custom_classes
    component = StatsCardComponent.new(
      title: "Test Stat",
      value: 123,
      icon_path: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
      class: "custom-class"
    )
    render_inline(component)

    assert_selector "div.custom-class"
    assert_text "Test Stat"
    assert_text "123"
  end

  def test_renders_icon_with_correct_path
    icon_path = "M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
    component = StatsCardComponent.new(
      title: "Organizations",
      value: 5,
      icon_path: icon_path
    )
    render_inline(component)

    assert_selector "path[d='#{icon_path}']"
  end
end
