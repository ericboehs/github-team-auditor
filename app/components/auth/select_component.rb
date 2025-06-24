# frozen_string_literal: true

class Auth::SelectComponent < ViewComponent::Base
  def initialize(form:, field:, options:, label: nil, prompt: nil, help_text: nil, required: false, autofocus: false, class: "")
    @form = form
    @field = field
    @options = options
    @label = label
    @prompt = prompt
    @help_text = help_text
    @required = required
    @autofocus = autofocus
    @extra_classes = binding.local_variable_get(:class)
  end

  private

  attr_reader :form, :field, :options, :prompt, :help_text, :required, :autofocus, :extra_classes

  def field_id
    "#{form.object_name}_#{field}"
  end

  def label_text
    return @label if @label.present?
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
    base_classes = "grid w-full cursor-default grid-cols-1 rounded-md py-1.5 pr-2 pl-3 text-left outline-1 -outline-offset-1 transition-colors duration-200 sm:text-sm/6"

    if has_errors?
      error_classes = "bg-white dark:bg-gray-700 text-red-900 dark:text-red-100 outline-red-300 dark:outline-red-600 focus:outline-2 focus:-outline-offset-2 focus:outline-red-600"
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

  def select_attributes
    attrs = {
      class: select_classes,
      id: field_id
    }

    attrs[:required] = true if required
    attrs[:autofocus] = true if autofocus
    attrs[:"aria-invalid"] = "true" if has_errors?
    attrs[:"aria-describedby"] = describedby_ids if describedby_ids.present?

    attrs
  end

  def selected_option_text
    return prompt if form.object.send(field).blank?

    # Find the selected option text
    if options.is_a?(Array)
      selected_option = options.find { |option| option.last.to_s == form.object.send(field).to_s }
      selected_option&.first || prompt
    else
      prompt
    end
  end

  def listbox_id
    "#{field_id}_listbox"
  end

  def listbox_button_id
    "#{field_id}_button"
  end

  def option_id(index)
    "#{field_id}_option_#{index}"
  end
end
