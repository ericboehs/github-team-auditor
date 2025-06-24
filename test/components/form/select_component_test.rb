# frozen_string_literal: true

require "test_helper"

class Form::SelectComponentTest < ViewComponent::TestCase
  def setup
    @user = User.new
    @form = ActionView::Helpers::FormBuilder.new(:user, @user, vc_test_controller.view_context, {})
    @options = [ [ "Option 1", "1" ], [ "Option 2", "2" ], [ "Option 3", "3" ] ]
  end

  def test_component_initializes_correctly
    component = Form::SelectComponent.new(
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

  def test_includes_button_styling_module
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    # Test that the component includes the ButtonStyling module
    assert component.class.ancestors.include?(ButtonStyling)
  end

  def test_field_id_method
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address", component.send(:field_id)
  end

  def test_has_errors_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    refute component.send(:has_errors?)
  end

  def test_has_errors_with_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert component.send(:has_errors?)
  end

  def test_error_messages_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal [], component.send(:error_messages)
  end

  def test_error_messages_with_errors
    @user.errors.add(:email_address, "is required")
    @user.errors.add(:email_address, "is invalid")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    messages = component.send(:error_messages)
    assert_equal [ "is required", "is invalid" ], messages
  end

  def test_error_id_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:error_id)
  end

  def test_error_id_with_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_error", component.send(:error_id)
  end

  def test_help_id_without_help_text
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:help_id)
  end

  def test_help_id_with_help_text
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help", component.send(:help_id)
  end

  def test_describedby_ids_without_help_or_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_only
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_errors_only
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_error", component.send(:describedby_ids)
  end

  def test_describedby_ids_with_help_text_and_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help user_email_address_error", component.send(:describedby_ids)
  end

  def test_label_text_with_label_key
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label_key: "test.label"
    )

    # Mock the translation method to avoid ViewComponent render dependency
    component.define_singleton_method(:t) { |key| "Custom Label" }
    assert_equal "Custom Label", component.send(:label_text)
  end

  def test_label_text_with_default_label
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "Email address", component.send(:label_text)
  end

  def test_select_classes_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      class: "extra-class"
    )

    classes = component.send(:select_classes)
    assert_includes classes, "border-gray-300 dark:border-gray-600"
    assert_includes classes, "bg-white dark:bg-gray-700"
    assert_includes classes, "focus:border-emerald-500"
    assert_includes classes, "extra-class"
    refute_includes classes, "border-red-300"
  end

  def test_select_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      class: "extra-class"
    )

    classes = component.send(:select_classes)
    assert_includes classes, "border-red-300 dark:border-red-600"
    assert_includes classes, "text-red-900 dark:text-red-100"
    assert_includes classes, "focus:ring-red-500"
    assert_includes classes, "extra-class"
    refute_includes classes, "border-gray-300"
  end

  def test_label_classes_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-gray-700 dark:text-gray-300"
    refute_includes classes, "text-red-700"
  end

  def test_label_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-red-700 dark:text-red-300"
    refute_includes classes, "text-gray-700"
  end

  def test_help_text_classes_without_errors
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-gray-500 dark:text-gray-400"
    refute_includes classes, "text-red-600"
  end

  def test_help_text_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-red-600 dark:text-red-400"
    refute_includes classes, "text-gray-500"
  end

  def test_select_attributes_minimal
    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    attrs = component.send(:select_attributes)
    assert_equal "user_email_address", attrs[:id]
    assert_includes attrs[:class], "border-gray-300"
    refute attrs.key?(:required)
    refute attrs.key?(:autofocus)
    refute attrs.key?(:"aria-invalid")
    refute attrs.key?(:"aria-describedby")
  end

  def test_select_attributes_with_all_options
    @user.errors.add(:email_address, "is required")

    component = Form::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text",
      required: true,
      autofocus: true
    )

    attrs = component.send(:select_attributes)
    assert_equal "user_email_address", attrs[:id]
    assert_equal true, attrs[:required]
    assert_equal true, attrs[:autofocus]
    assert_equal "true", attrs[:"aria-invalid"]
    assert_equal "user_email_address_help user_email_address_error", attrs[:"aria-describedby"]
  end
end
