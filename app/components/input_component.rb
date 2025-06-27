# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  def initialize(form:, field:, label: nil, type: :text, required: false, autocomplete: nil, placeholder: nil, error: nil, forgot_password_link: nil, help_text: nil, i18n_scope: nil, **options)
    @form = form
    @field = field
    @label = label
    @type = type
    @required = required
    @autocomplete = autocomplete
    @placeholder = placeholder
    @error = error
    @forgot_password_link = forgot_password_link
    @help_text = help_text
    @i18n_scope = i18n_scope
    @options = options
  end

  private

  attr_reader :form, :field, :label, :type, :required, :autocomplete, :placeholder, :error, :forgot_password_link, :help_text, :options, :i18n_scope

  def input_classes
    base_classes = "block w-full rounded-md bg-white px-3 py-1.5 text-base text-gray-900 outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline-2 focus:-outline-offset-2 focus:outline-vads-primary sm:text-sm/6"
    dark_classes = "dark:bg-white/5 dark:text-white dark:placeholder:text-gray-500 dark:outline-white/10 dark:focus:outline-vads-primary-dark"

    if error
      "#{base_classes} #{dark_classes} outline-red-300 dark:outline-red-400/50 placeholder:text-red-300 dark:placeholder:text-red-400 focus:outline-red-600 dark:focus:outline-red-500"
    else
      "#{base_classes} #{dark_classes}"
    end
  end

  def field_id
    "#{form.object_name}_#{field}"
  end

  def before_render
    @resolved_label = resolve_label
    @resolved_placeholder = resolve_placeholder
    @resolved_help_text = resolve_help_text
  end

  def label_text
    @resolved_label || form.object.class.human_attribute_name(field)
  end

  def placeholder_text
    @resolved_placeholder
  end

  def help_text_value
    @resolved_help_text
  end

  private

  def resolve_label
    return label if label.present?
    return inferred_i18n("label") if i18n_scope && i18n_key_exists?("#{i18n_scope}.#{field}_label")
    nil
  end

  def resolve_placeholder
    return placeholder if placeholder.present?
    return inferred_i18n("placeholder") if i18n_scope && i18n_key_exists?("#{i18n_scope}.#{field}_placeholder")
    nil
  end

  def resolve_help_text
    return help_text if help_text.present?
    return inferred_i18n("help") if i18n_scope && i18n_key_exists?("#{i18n_scope}.#{field}_help")
    nil
  end

  def inferred_i18n(suffix)
    helpers.t("#{i18n_scope}.#{field}_#{suffix}")
  end

  def i18n_key_exists?(key)
    I18n.exists?(key)
  end

  def label_with_required_indicator
    if required
      (label_text + ' <span class="text-red-500 ml-1" aria-label="required">*</span>').html_safe
    else
      label_text
    end
  end
end
