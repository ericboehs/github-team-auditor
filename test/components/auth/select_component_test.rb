# frozen_string_literal: true

require "test_helper"

class Auth::SelectComponentTest < ViewComponent::TestCase
  def setup
    @user = User.new
    @form = ActionView::Helpers::FormBuilder.new(:user, @user, vc_test_controller.view_context, {})
    @options = [ [ "Option 1", "1" ], [ "Option 2", "2" ], [ "Option 3", "3" ] ]
  end

  def test_component_initializes_correctly
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label: "Test Label",
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
    assert_equal "Test Label", component.instance_variable_get(:@label)
    assert_equal "Choose option", component.instance_variable_get(:@prompt)
    assert_equal "Help text", component.instance_variable_get(:@help_text)
    assert_equal true, component.instance_variable_get(:@required)
    assert_equal true, component.instance_variable_get(:@autofocus)
    assert_equal "custom-class", component.instance_variable_get(:@extra_classes)
  end

  def test_field_id_method
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address", component.send(:field_id)
  end

  def test_has_errors_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    refute component.send(:has_errors?)
  end

  def test_has_errors_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert component.send(:has_errors?)
  end

  def test_error_messages_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal [], component.send(:error_messages)
  end

  def test_error_messages_with_errors
    @user.errors.add(:email_address, "is required")
    @user.errors.add(:email_address, "is invalid")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    messages = component.send(:error_messages)
    assert_equal [ "is required", "is invalid" ], messages
  end

  def test_listbox_id_method
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_listbox", component.send(:listbox_id)
  end

  def test_option_id_method
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_option_0", component.send(:option_id, 0)
    assert_equal "user_email_address_option_5", component.send(:option_id, 5)
  end

  def test_listbox_button_id_method
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_button", component.send(:listbox_button_id)
  end

  def test_selected_option_text_with_blank_value
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      prompt: "Select option"
    )

    assert_equal "Select option", component.send(:selected_option_text)
  end

  def test_selected_option_text_with_selected_value
    @user.email_address = "2"

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      prompt: "Select option"
    )

    assert_equal "Option 2", component.send(:selected_option_text)
  end

  def test_selected_option_text_with_invalid_value
    @user.email_address = "999"

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      prompt: "Select option"
    )

    assert_equal "Select option", component.send(:selected_option_text)
  end

  def test_label_text_with_explicit_label
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      label: "Custom Label"
    )

    assert_equal "Custom Label", component.send(:label_text)
  end

  def test_label_text_without_explicit_label
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "Email address", component.send(:label_text)
  end

  def test_select_classes_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:select_classes)
    assert_includes classes, "bg-white dark:bg-gray-700"
    assert_includes classes, "text-gray-900 dark:text-white"
    assert_includes classes, "outline-gray-300 dark:outline-gray-600"
  end

  def test_select_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:select_classes)
    assert_includes classes, "text-red-900 dark:text-red-100"
    assert_includes classes, "outline-red-300 dark:outline-red-600"
  end

  def test_select_classes_with_extra_classes
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      class: "custom-class"
    )

    classes = component.send(:select_classes)
    assert_includes classes, "custom-class"
  end

  def test_label_classes_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-gray-900 dark:text-gray-300"
  end

  def test_label_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:label_classes)
    assert_includes classes, "text-red-700 dark:text-red-300"
  end

  def test_help_text_classes_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-gray-600 dark:text-gray-400"
  end

  def test_help_text_classes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    classes = component.send(:help_text_classes)
    assert_includes classes, "text-red-600 dark:text-red-400"
  end

  def test_select_attributes_basic
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    attrs = component.send(:select_attributes)
    assert_equal "user_email_address", attrs[:id]
    assert_includes attrs[:class], "bg-white"
    refute attrs.key?(:required)
    refute attrs.key?(:autofocus)
    refute attrs.key?(:"aria-invalid")
    refute attrs.key?(:"aria-describedby")
  end

  def test_select_attributes_with_required
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      required: true
    )

    attrs = component.send(:select_attributes)
    assert_equal true, attrs[:required]
  end

  def test_select_attributes_with_autofocus
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      autofocus: true
    )

    attrs = component.send(:select_attributes)
    assert_equal true, attrs[:autofocus]
  end

  def test_select_attributes_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    attrs = component.send(:select_attributes)
    assert_equal "true", attrs[:"aria-invalid"]
    assert_equal "user_email_address_error", attrs[:"aria-describedby"]
  end

  def test_select_attributes_with_help_text_and_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    attrs = component.send(:select_attributes)
    assert_equal "user_email_address_help user_email_address_error", attrs[:"aria-describedby"]
  end

  def test_selected_option_text_with_non_array_options
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: "not an array",
      prompt: "Select option"
    )

    assert_equal "Select option", component.send(:selected_option_text)
  end

  def test_selected_option_text_with_nil_prompt
    @user.email_address = "1"

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "Option 1", component.send(:selected_option_text)
  end

  def test_error_id_without_errors
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:error_id)
  end

  def test_error_id_with_errors
    @user.errors.add(:email_address, "is required")

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_equal "user_email_address_error", component.send(:error_id)
  end

  def test_help_id_without_help_text
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options
    )

    assert_nil component.send(:help_id)
  end

  def test_help_id_with_help_text
    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      help_text: "Help text"
    )

    assert_equal "user_email_address_help", component.send(:help_id)
  end

  def test_selected_option_text_when_option_not_found
    @user.email_address = "999"  # Value not in options

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: @options,
      prompt: nil  # No prompt to test the || path on line 106
    )

    # When selected_option is nil and prompt is nil, should return nil
    assert_nil component.send(:selected_option_text)
  end

  def test_selected_option_text_with_non_array_and_field_value
    @user.email_address = "some_value"  # Set a field value

    component = Auth::SelectComponent.new(
      form: @form,
      field: :email_address,
      options: 12345,  # Not an array to trigger else branch
      prompt: "Select option"
    )

    # Should return prompt when options is not an array (line 107)
    assert_equal "Select option", component.send(:selected_option_text)
  end
end
