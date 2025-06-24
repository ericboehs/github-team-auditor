# frozen_string_literal: true

class TextareaComponent < ViewComponent::Base
  def initialize(form:, field:, label: nil, placeholder: nil, help_text: nil, required: false, autofocus: false, rows: 3, class: "")
    @form = form
    @field = field
    @label = label
    @placeholder = placeholder
    @help_text = help_text
    @required = required
    @autofocus = autofocus
    @rows = rows
    @extra_classes = binding.local_variable_get(:class)
  end

  private

  attr_reader :form, :field, :label, :placeholder, :help_text, :required, :autofocus, :rows, :extra_classes

  def field_id
    "#{form.object_name}_#{field}"
  end

  def label_text
    return label if label.present?
    form.object.class.human_attribute_name(field)
  end

  def error_messages
    return [] unless form.object.errors[field].any?
    form.object.errors[field]
  end

  def has_errors?
    error_messages.any?
  end

  def textarea_classes
    base_classes = "block w-full rounded-md px-3 py-1.5 text-base outline-1 -outline-offset-1 placeholder:text-gray-400 transition-colors duration-200 sm:text-sm/6"

    if has_errors?
      error_classes = "bg-white dark:bg-gray-700 text-red-900 dark:text-red-100 outline-red-300 dark:outline-red-600 placeholder:text-red-300 dark:placeholder:text-red-400 focus:outline-2 focus:-outline-offset-2 focus:outline-red-600"
      "#{base_classes} #{error_classes} #{extra_classes}".strip
    else
      normal_classes = "bg-white dark:bg-gray-700 text-gray-900 dark:text-white outline-gray-300 dark:outline-gray-600 focus:outline-2 focus:-outline-offset-2 focus:outline-emerald-600 dark:focus:outline-emerald-500"
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

  def textarea_attributes
    attrs = {
      class: textarea_classes,
      id: field_id,
      rows: rows
    }

    attrs[:placeholder] = placeholder if placeholder.present?
    attrs[:required] = true if required
    attrs[:autofocus] = true if autofocus
    attrs[:"aria-invalid"] = "true" if has_errors?
    attrs[:"aria-describedby"] = describedby_ids if describedby_ids.present?

    attrs
  end
end
