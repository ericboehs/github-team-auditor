# frozen_string_literal: true

require "test_helper"

class TextareaComponentTest < ViewComponent::TestCase
  def setup
    @user = User.new
    @form = ActionView::Helpers::FormBuilder.new(:user, @user, vc_test_controller.view_context, {})
  end

  def teardown
    # Clear test translations to prevent interference between tests
    I18n.backend.store_translations(:en, test: nil)
  end

  def test_component_initializes_correctly
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      label: "Test Label",
      placeholder: "Enter text...",
      help_text: "Help text",
      required: true,
      autofocus: true,
      rows: 5,
      class: "custom-class"
    )

    assert_not_nil component
    assert_equal @form, component.instance_variable_get(:@form)
    assert_equal :email_address, component.instance_variable_get(:@field)
    assert_equal "Test Label", component.instance_variable_get(:@label)
    assert_equal "Enter text...", component.instance_variable_get(:@placeholder)
    assert_equal "Help text", component.instance_variable_get(:@help_text)
    assert_equal true, component.instance_variable_get(:@required)
    assert_equal true, component.instance_variable_get(:@autofocus)
    assert_equal 5, component.instance_variable_get(:@rows)
    assert_equal "custom-class", component.instance_variable_get(:@extra_classes)
  end

  def test_field_id_method
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_equal "user_email_address", component.send(:field_id)
  end

  def test_has_errors_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    refute component.send(:has_errors?)
  end

  def test_has_errors_with_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert component.send(:has_errors?)
  end

  def test_error_messages_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_equal [], component.send(:error_messages)
  end

  def test_error_messages_with_errors
    @user.errors.add(:email_address, "is required")
    @user.errors.add(:email_address, "is invalid")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    messages = component.send(:error_messages)
    assert_equal [ "is required", "is invalid" ], messages
  end

  def test_error_id_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_nil component.send(:error_id)
  end

  def test_error_id_with_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_equal "user_email_address_error", component.send(:error_id)
  end

  def test_help_id_without_help_text
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_nil component.send(:help_id)
  end

  def test_help_id_with_help_text
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help", component.send(:help_id)
  end

  def test_describedby_ids_without_help_or_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_nil component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_only
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_errors_only
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    assert_equal "user_email_address_error", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_and_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help user_email_address_error", component.send(:describedby_ids)
  end

  def test_label_text_with_custom_label
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      label: "Custom Label"
    )
    render_inline(component)

    assert_selector "label", text: "Custom Label"
  end

  def test_label_text_with_default_label
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )
    render_inline(component)

    assert_selector "label", text: "Email address"
  end

  def test_textarea_classes_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      class: "extra-class"
    )

    classes = component.send(:textarea_classes)
    assert_includes classes, "bg-white dark:bg-gray-700"
    assert_includes classes, "text-gray-900 dark:text-white"
    assert_includes classes, "focus:outline-emerald-600"
    assert_includes classes, "extra-class"
    refute_includes classes, "text-red-900"
  end

  def test_textarea_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      class: "extra-class"
    )

    classes = component.send(:textarea_classes)
    assert_includes classes, "text-red-900 dark:text-red-100"
    assert_includes classes, "outline-red-300 dark:outline-red-600"
    assert_includes classes, "focus:outline-red-600"
    assert_includes classes, "extra-class"
    refute_includes classes, "text-gray-900"
  end

  def test_label_classes_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-gray-900 dark:text-gray-300"
    refute_includes classes, "text-red-700"
  end

  def test_label_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-red-700 dark:text-red-300"
    refute_includes classes, "text-gray-900"
  end

  def test_help_text_classes_without_errors
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-gray-600 dark:text-gray-400"
    refute_includes classes, "text-red-600"
  end

  def test_help_text_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-red-600 dark:text-red-400"
    refute_includes classes, "text-gray-600"
  end

  def test_textarea_attributes_minimal
    component = TextareaComponent.new(
      form: @form,
      field: :email_address
    )

    attrs = component.send(:textarea_attributes)
    assert_equal "user_email_address", attrs[:id]
    assert_equal 3, attrs[:rows]
    assert_includes attrs[:class], "bg-white"
    refute attrs.key?(:placeholder)
    refute attrs.key?(:required)
    refute attrs.key?(:autofocus)
    refute attrs.key?(:"aria-invalid")
    refute attrs.key?(:"aria-describedby")
  end

  def test_textarea_attributes_with_all_options
    @user.errors.add(:email_address, "is required")

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      placeholder: "Enter text...",
      help_text: "Help text",
      required: true,
      autofocus: true,
      rows: 5
    )
    render_inline(component)

    assert_selector "textarea[id='user_email_address']"
    assert_selector "textarea[rows='5']"
    assert_selector "textarea[placeholder='Enter text...']"
    assert_selector "textarea[required]"
    assert_selector "textarea[autofocus]"
    assert_selector "textarea[aria-invalid='true']"
    assert_selector "textarea[aria-describedby='user_email_address_help user_email_address_error']"
  end

  def test_infers_label_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_label: "Test Email Label" } })

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "label", text: "Test Email Label"
  end

  def test_infers_placeholder_from_i18n_scope
    # Add test i18n key
    I18n.backend.store_translations(:en, test: { form: { email_address_placeholder: "Enter notes here..." } })

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      i18n_scope: "test.form"
    )
    render_inline(component)

    assert_selector "textarea[placeholder='Enter notes here...']"
  end

  def test_falls_back_to_explicit_values_when_no_i18n_scope
    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      label: "Explicit Label",
      placeholder: "Explicit Placeholder"
    )
    render_inline(component)

    assert_selector "label", text: "Explicit Label"
    assert_selector "textarea[placeholder='Explicit Placeholder']"
  end

  def test_falls_back_when_i18n_key_does_not_exist
    # Clear any existing test translations
    I18n.backend.store_translations(:en, test: { form: {} })

    component = TextareaComponent.new(
      form: @form,
      field: :email_address,
      i18n_scope: "test.form"
    )
    render_inline(component)

    # Should fall back to humanized attribute name
    assert_selector "label", text: "Email address"
    assert_no_selector "textarea[placeholder]"
  end
end
