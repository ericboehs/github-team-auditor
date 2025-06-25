# frozen_string_literal: true

require "test_helper"

class InputComponentTest < ViewComponent::TestCase
  def teardown
    # Clear test translations to prevent interference between tests
    I18n.backend.store_translations(:en, test: nil)
  end
  def test_renders_email_input
    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :email_address,
      label: "Email",
      type: :email,
      required: true
    )
    render_inline(component)

    assert_selector "input[type='email']"
    assert_selector "label", text: "Email"
    assert_selector "input[required]"
  end

  def test_renders_password_input
    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :password,
      label: "Password",
      type: :password
    )
    render_inline(component)

    assert_selector "input[type='password']"
    assert_selector "label", text: "Password"
  end

  def test_infers_label_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_label: "Test Email Label" } })

    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :email_address,
      type: :text,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "label", text: "Test Email Label"
  end

  def test_infers_placeholder_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_placeholder: "Enter your email" } })

    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :email_address,
      type: :email,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "input[placeholder='Enter your email']"
  end

  def test_falls_back_to_explicit_values_when_no_i18n_scope
    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :email_address,
      label: "Explicit Label",
      placeholder: "Explicit Placeholder",
      type: :text
    )
    render_inline(component)

    assert_selector "label", text: "Explicit Label"
    assert_selector "input[placeholder='Explicit Placeholder']"
  end

  def test_infers_help_text_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_help: "Help text from i18n" } })

    form = ActionView::Helpers::FormBuilder.new(:user, User.new, vc_test_controller.view_context, {})
    component = InputComponent.new(
      form: form,
      field: :email_address,
      type: :text,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "p", text: "Help text from i18n"
  end
end
