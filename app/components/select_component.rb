# frozen_string_literal: true

class SelectComponent < ViewComponent::Base
  def initialize(form:, field:, options:, label: nil, label_key: nil, prompt: nil, help_text: nil, required: false, autofocus: false, class: "", i18n_scope: nil, **html_options)
    @form = form
    @field = field
    @options = options
    @label = label
    @label_key = label_key
    @prompt = prompt
    @help_text = help_text
    @required = required
    @autofocus = autofocus
    @extra_classes = binding.local_variable_get(:class)
    @i18n_scope = i18n_scope
    @html_options = html_options
  end

  private

  attr_reader :form, :field, :options, :label, :label_key, :prompt, :help_text, :required, :autofocus, :extra_classes, :html_options, :i18n_scope

  def field_id
    "#{form.object_name}_#{field}"
  end

  def before_render
    @resolved_label = resolve_label
    @resolved_prompt = resolve_prompt
    @resolved_help_text = resolve_help_text
  end

  def label_text
    @resolved_label || form.object.class.human_attribute_name(field)
  end

  def prompt_text
    @resolved_prompt
  end

  def help_text_value
    @resolved_help_text
  end

  private

  def resolve_label
    return label if label.present?
    return helpers.t(label_key) if label_key.present?
    return inferred_i18n("label") if i18n_scope && i18n_key_exists?("#{i18n_scope}.#{field}_label")
    nil
  end

  def resolve_prompt
    return prompt if prompt.present?
    return inferred_i18n("prompt") if i18n_scope && i18n_key_exists?("#{i18n_scope}.#{field}_prompt")
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

  def error_messages
    return [] unless form.object.errors[field].any?
    form.object.errors[field]
  end

  def has_errors?
    error_messages.any?
  end

  def select_classes
    base_classes = "col-start-1 row-start-1 w-full appearance-none rounded-md bg-white py-1.5 pr-8 pl-3 text-base text-gray-900 outline-1 -outline-offset-1 transition-colors duration-200 sm:text-sm/6"

    if has_errors?
      error_classes = "outline-red-300 dark:outline-red-600 text-red-900 dark:text-red-100 focus:outline-2 focus:-outline-offset-2 focus:outline-red-500 dark:bg-red-50"
      "#{base_classes} #{error_classes} #{extra_classes}".strip
    else
      normal_classes = "outline-gray-300 dark:outline-gray-600 dark:bg-gray-700 dark:text-white focus:outline-2 focus:-outline-offset-2 focus:outline-emerald-600"
      "#{base_classes} #{normal_classes} #{extra_classes}".strip
    end
  end

  def label_classes
    base_classes = "block text-sm/6 font-medium"

    if has_errors?
      "#{base_classes} text-red-700 dark:text-red-300"
    else
      "#{base_classes} text-gray-900 dark:text-gray-300"
    end
  end

  def help_text_classes
    base_classes = "mt-2 text-sm"

    if has_errors?
      "#{base_classes} text-red-600 dark:text-red-400"
    else
      "#{base_classes} text-gray-600 dark:text-gray-400"
    end
  end

  def error_id
    "#{field_id}_error" if has_errors?
  end

  def help_id
    "#{field_id}_help" if help_text_value.present?
  end

  def describedby_ids
    ids = []
    ids << help_id if help_text_value.present?
    ids << error_id if has_errors?
    ids.compact.join(" ").presence
  end

  def select_attributes
    attrs = {
      class: select_classes,
      id: field_id
    }

    attrs[:required] = true if required
    attrs[:autofocus] = true if autofocus
    attrs[:"aria-invalid"] = "true" if has_errors?
    attrs[:"aria-describedby"] = describedby_ids if describedby_ids.present?

    # Merge any additional HTML options
    attrs.merge(html_options)
  end
end
