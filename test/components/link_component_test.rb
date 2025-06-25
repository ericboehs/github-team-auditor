# frozen_string_literal: true

require "test_helper"

class LinkComponentTest < ViewComponent::TestCase
  def test_renders_link_with_url
    component = LinkComponent.new(
      url: "/test-url",
      text: "Test Link"
    )
    render_inline(component)

    assert_selector "a[href='/test-url']", text: "Test Link"
    assert_selector "a.font-semibold"
    assert_selector "a.text-emerald-600"
  end

  def test_renders_link_with_text
    component = LinkComponent.new(
      url: "/test-url",
      text: "Custom Link Text"
    )
    render_inline(component)

    assert_selector "a[href='/test-url']", text: "Custom Link Text"
  end

  def test_renders_link_not_centered
    component = LinkComponent.new(
      url: "/test-url",
      text: "Test Link",
      centered: false
    )
    render_inline(component)

    assert_selector "a[href='/test-url']", text: "Test Link"
    # Should not have text-center class when not centered
    assert_no_selector ".text-center"
  end
end
