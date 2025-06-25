# frozen_string_literal: true

require "test_helper"

class SelectComponentTest < ViewComponent::TestCase
  def setup
    @user = User.new
    @form = ActionView::Helpers::FormBuilder.new(:user, @user, vc_test_controller.view_context, {})
    @options = [ [ "Option 1", "1" ], [ "Option 2", "2" ], [ "Option 3", "3" ] ]
  end

  def test_component_initializes_correctly
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label_key: "test.label",
      prompt: "Choose option",
      help_text: "Help text",
      required: true,
      autofocus: true,
      class: "custom-class"
    )

    assert_not_nil component
    assert_equal @form, component.instance_variable_get(:@form)
    assert_equal :email_address, component.instance_variable_get(:@field)
    assert_equal @options, component.instance_variable_get(:@options)
    assert_equal "test.label", component.instance_variable_get(:@label_key)
    assert_equal "Choose option", component.instance_variable_get(:@prompt)
    assert_equal "Help text", component.instance_variable_get(:@help_text)
    assert_equal true, component.instance_variable_get(:@required)
    assert_equal true, component.instance_variable_get(:@autofocus)
    assert_equal "custom-class", component.instance_variable_get(:@extra_classes)
  end

  def test_component_initializes_with_label_parameter
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label: "Custom Label"
    )

    assert_equal "Custom Label", component.instance_variable_get(:@label)
  end

  def test_field_id_method
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address", component.send(:field_id)
  end

  def test_has_errors_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    refute component.send(:has_errors?)
  end

  def test_has_errors_with_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert component.send(:has_errors?)
  end

  def test_error_messages_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal [], component.send(:error_messages)
  end

  def test_error_messages_with_errors
    @user.errors.add(:email_address, "is required")
    @user.errors.add(:email_address, "is invalid")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    messages = component.send(:error_messages)
    assert_equal [ "is required", "is invalid" ], messages
  end

  def test_error_id_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:error_id)
  end

  def test_error_id_with_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_error", component.send(:error_id)
  end

  def test_help_id_without_help_text
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:help_id)
  end

  def test_help_id_with_help_text
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )
    render_inline(component)

    assert_equal "user_email_address_help", component.send(:help_id)
  end

  def test_describedby_ids_without_help_or_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_only
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )
    render_inline(component)

    assert_equal "user_email_address_help", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_errors_only
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_error", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_and_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )
    render_inline(component)

    assert_equal "user_email_address_help user_email_address_error", component.send(:describedby_ids)
  end

  def test_label_text_with_explicit_label
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label: "Explicit Label"
    )
    render_inline(component)

    assert_selector "label", text: "Explicit Label"
  end

  def test_label_text_with_label_key
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { label: "Custom Label from Key" })

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label_key: "test.label"
    )
    render_inline(component)

    assert_selector "label", text: "Custom Label from Key"
  end

  def test_label_text_with_default_label
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )
    render_inline(component)

    assert_selector "label", text: "Email address"
  end

  def test_select_classes_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      class: "extra-class"
    )

    classes = component.send(:select_classes)
    assert_includes classes, "outline-gray-300 dark:outline-gray-600"
    assert_includes classes, "bg-white"
    assert_includes classes, "dark:bg-gray-700"
    assert_includes classes, "focus:outline-blue-800"
    assert_includes classes, "appearance-none"
    assert_includes classes, "extra-class"
    refute_includes classes, "outline-red-300"
  end

  def test_select_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      class: "extra-class"
    )

    classes = component.send(:select_classes)
    assert_includes classes, "outline-red-300 dark:outline-red-600"
    assert_includes classes, "text-red-900 dark:text-red-100"
    assert_includes classes, "focus:outline-red-500"
    assert_includes classes, "extra-class"
    refute_includes classes, "outline-gray-300"
  end

  def test_label_classes_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-gray-900 dark:text-gray-300"
    refute_includes classes, "text-red-700"
  end

  def test_label_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-red-700 dark:text-red-300"
    refute_includes classes, "text-gray-900"
  end

  def test_help_text_classes_without_errors
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-gray-600 dark:text-gray-400"
    refute_includes classes, "text-red-600"
  end

  def test_help_text_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-red-600 dark:text-red-400"
    refute_includes classes, "text-gray-600"
  end

  def test_select_attributes_minimal
    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    attrs = component.send(:select_attributes)
    assert_equal "user_email_address", attrs[:id]
    assert_includes attrs[:class], "outline-gray-300"
    refute attrs.key?(:required)
    refute attrs.key?(:autofocus)
    refute attrs.key?(:"aria-invalid")
    refute attrs.key?(:"aria-describedby")
  end

  def test_select_attributes_with_all_options
    @user.errors.add(:email_address, "is required")

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text",
      required: true,
      autofocus: true
    )
    render_inline(component)

    assert_selector "select[id='user_email_address']"
    assert_selector "select[required]"
    assert_selector "select[autofocus]"
    assert_selector "select[aria-invalid='true']"
    assert_selector "select[aria-describedby='user_email_address_help user_email_address_error']"
  end

  def teardown
    # Clear test translations to prevent interference between tests
    I18n.backend.store_translations(:en, test: nil)
  end

  def test_infers_label_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_label: "Select Email Label" } })

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "label", text: "Select Email Label"
  end

  def test_infers_prompt_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_prompt: "Choose an email" } })

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      i18n_scope: "test.form"
    )
    render_inline(component)

    # Check that the prompt text is included in the select
    assert_match /Choose an email/, rendered_content
  end

  def test_infers_help_text_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_help: "Select help from i18n" } })

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "p", text: "Select help from i18n"
  end

  def test_falls_back_when_i18n_key_does_not_exist
    # Clear any existing test translations
    I18n.backend.store_translations(:en, test: { form: {} })

    component = SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      i18n_scope: "test.form"
    )
    render_inline(component)

    # Should fall back to humanized attribute name
    assert_selector "label", text: "Email address"
  end
end
