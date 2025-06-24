# frozen_string_literal: true

class SelectComponent < ViewComponent::Base
  def initialize(form:, field:, options:, label: nil, label_key: nil, prompt: nil, help_text: nil, required: false, autofocus: false, class: "", **html_options)
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
    @html_options = html_options
  end

  private

  attr_reader :form, :field, :options, :label, :label_key, :prompt, :help_text, :required, :autofocus, :extra_classes, :html_options

  def field_id
    "#{form.object_name}_#{field}"
  end

  def label_text
    return @label if @label.present?
    return t(label_key) if label_key.present?
    form.object.class.human_attribute_name(field)
  end

  def error_messages
    return [] unless form.object.errors[field].any?
    form.object.errors[field]
  end

  def has_errors?
    error_messages.any?
  end

  def select_classes
    base_classes = "mt-1 block w-full rounded-md shadow-sm transition-colors duration-200"

    if has_errors?
      error_classes = "border-red-300 dark:border-red-600 text-red-900 dark:text-red-100 placeholder-red-300 dark:placeholder-red-400 focus:ring-red-500 focus:border-red-500"
      "#{base_classes} #{error_classes} #{extra_classes}".strip
    else
      normal_classes = "border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:border-emerald-500 focus:ring-emerald-500"
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
    "#{field_id}_help" if help_text.present?
  end

  def describedby_ids
    ids = []
    ids << help_id if help_text.present?
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
