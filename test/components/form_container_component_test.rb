# frozen_string_literal: true

require "test_helper"

class FormContainerComponentTest < ViewComponent::TestCase
  def test_renders_with_title_key
    component = FormContainerComponent.new(title_key: "auth.sign_in.title")
    render_inline(component) { "Form content" }

    assert_selector "h2", text: "Sign in to your account"
    assert_text "Form content"
    assert_selector ".flex.min-h-full.flex-col"
  end

  def test_renders_with_title_and_subtitle
    component = FormContainerComponent.new(
      title_key: "auth.sign_in.title",
      title: "Custom Title",
      subtitle: "Custom Subtitle"
    )
    render_inline(component) { "Form content" }

    assert_selector "h2", text: "Custom Title"
    assert_selector "p", text: "Custom Subtitle"
  end

  def test_renders_logo
    component = FormContainerComponent.new(title_key: "auth.sign_in.title")
    render_inline(component) { "Form content" }

    assert_selector "img[alt='GitHub Team Auditor']"
  end

  def test_renders_with_title_key_only
    component = FormContainerComponent.new(title_key: "auth.sign_up.title")
    render_inline(component) { "Form content" }

    assert_selector "h2", text: "Create your account"
    assert_text "Form content"
  end

  def test_renders_with_subtitle_key
    component = FormContainerComponent.new(
      title_key: "auth.sign_in.title",
      subtitle_key: "auth.sign_in.subtitle"
    )
    render_inline(component) { "Form content" }

    assert_selector "h2", text: "Sign in to your account"
    assert_selector "p", text: "Welcome back to GitHub Team Auditor"
  end

  def test_renders_with_nil_title_key
    component = FormContainerComponent.new(
      title_key: nil,
      title: "Custom Title"
    )
    render_inline(component) { "Form content" }

    assert_selector "h2", text: "Custom Title"
    assert_text "Form content"
  end

  def test_renders_with_falsy_title_and_nil_title_key
    component = FormContainerComponent.new(
      title_key: nil,
      title: ""
    )
    render_inline(component) { "Form content" }

    # Should render without title when both are falsy
    assert_no_selector "h2"
    assert_text "Form content"
  end

  def test_renders_with_falsy_title_key_returns_nil
    component = FormContainerComponent.new(
      title_key: false,
      title: nil
    )
    render_inline(component) { "Form content" }

    # Should render without title when title_key is falsy and title is nil
    assert_no_selector "h2"
    assert_text "Form content"
  end
end
