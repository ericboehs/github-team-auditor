# frozen_string_literal: true

require "test_helper"

class StatusBadgeComponentTest < ViewComponent::TestCase
  def test_renders_active_status_badge
    component = StatusBadgeComponent.new(status: "active")
    render_inline(component)

    assert_selector "span.bg-blue-100.text-blue-800"
    assert_text "Active"
  end

  def test_renders_completed_status_badge
    component = StatusBadgeComponent.new(status: "completed")
    render_inline(component)

    assert_selector "span.bg-purple-100.text-purple-800"
    assert_text "Completed"
  end

  def test_renders_draft_status_badge
    component = StatusBadgeComponent.new(status: "draft")
    render_inline(component)

    assert_selector "span.bg-yellow-100.text-yellow-800"
    assert_text "Draft"
  end

  def test_renders_pending_status_badge
    component = StatusBadgeComponent.new(status: "pending")
    render_inline(component)

    assert_selector "span.bg-yellow-100.text-yellow-800"
    assert_text "Pending"
  end

  def test_renders_validated_status_badge
    component = StatusBadgeComponent.new(status: "validated")
    render_inline(component)

    assert_selector "span.bg-green-100.text-green-800"
    assert_text "Validated"
  end

  def test_renders_removed_status_badge
    component = StatusBadgeComponent.new(status: "removed")
    render_inline(component)

    assert_selector "span.bg-red-100.text-red-800"
    assert_text "Removed"
  end

  def test_renders_maintainer_badge
    component = StatusBadgeComponent.new(status: "maintainer")
    render_inline(component)

    assert_selector "span.bg-purple-100.text-purple-800"
    assert_text "Maintainer"
  end

  def test_renders_government_badge
    component = StatusBadgeComponent.new(status: "government")
    render_inline(component)

    assert_selector "span.bg-emerald-100.text-emerald-800"
    assert_text "Gov"
  end

  def test_renders_unknown_status_with_default_styling
    component = StatusBadgeComponent.new(status: "unknown")
    render_inline(component)

    assert_selector "span.bg-gray-100.text-gray-800"
    assert_text "Unknown"
  end

  def test_applies_custom_classes
    component = StatusBadgeComponent.new(status: "active", class: "w-fit")
    render_inline(component)

    assert_selector "span.w-fit"
    assert_text "Active"
  end

  def test_accepts_symbol_status
    component = StatusBadgeComponent.new(status: :active)
    render_inline(component)

    assert_selector "span.bg-blue-100.text-blue-800"
    assert_text "Active"
  end
end
