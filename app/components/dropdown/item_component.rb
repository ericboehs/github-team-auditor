class Dropdown::ItemComponent < ViewComponent::Base
  def initialize(type:, **options)
    @type = type
    @options = options
  end

  private

  attr_reader :type, :options

  def render?
    type.in?([ :link, :form, :divider ])
  end

  def render_item
    case type
    when :divider
      render_divider_item
    when :form
      render_form_item
    else
      render_link_item
    end
  end

  def render_link_item
    link_classes = item_hover_classes
    icon_classes = item_icon_classes

    # Merge dropdown close action with any existing data actions
    link_data = (options[:data] || {}).merge({ action: "click->dropdown#closeAction" })

    link_to options[:url],
            class: link_classes,
            role: "menuitem",
            tabindex: "0",
            id: options[:id],
            method: options[:method],
            target: options[:target],
            data: link_data do
      concat render_icon
      concat options[:text]
    end
  end

  def render_divider_item
    content_tag :div, class: "border-t border-gray-100 dark:border-gray-700" do
      # Empty divider
    end
  end

  def render_form_item
    button_classes = options[:disabled] ? disabled_button_classes : enabled_button_classes
    icon_classes = options[:disabled] ? disabled_icon_classes : item_icon_classes

    # Add flash message clearing for sync and find issues actions
    action_data = { action: "click->dropdown#closeAction" }
    if options[:url]&.include?("sync") || options[:url]&.include?("find_issue_correlations")
      action_data[:action] = "click->dropdown#closeAction click->dropdown#clearFlashMessages"
    end

    form_with url: options[:url],
              method: options[:method],
              local: true,
              data: options[:data],
              class: "contents" do |form|
      content = ""

      # Add hidden field if specified
      if options[:hidden_field]
        content += form.hidden_field options[:hidden_field][:name], value: options[:hidden_field][:value]
      end

      content += form.button type: :submit,
                          class: button_classes,
                          role: "menuitem",
                          tabindex: "0",
                          id: options[:id],
                          disabled: options[:disabled],
                          data: action_data do
        concat content_tag(:svg, options[:icon_path]&.html_safe, class: icon_classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "aria-hidden": "true", "data-slot": "icon")
        concat options[:text]
      end

      content.html_safe
    end
  end

  def render_icon
    return "" unless options[:icon_path]

    content_tag(:svg, options[:icon_path]&.html_safe,
                class: item_icon_classes,
                viewBox: "0 0 24 24",
                fill: "none",
                stroke: "currentColor",
                "aria-hidden": "true",
                "data-slot": "icon")
  end

  def item_hover_classes
    base_classes = "group flex items-center px-4 py-2 text-sm"

    case options[:hover_color]
    when "primary"
      "#{base_classes} text-gray-700 dark:text-gray-200 hover:bg-blue-600 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white focus:bg-blue-600 focus:text-white dark:focus:bg-blue-500 dark:focus:text-white focus:outline-none"
    when "success"
      "#{base_classes} text-gray-700 dark:text-gray-200 hover:bg-green-600 hover:text-white dark:hover:bg-green-500 dark:hover:text-white focus:bg-green-600 focus:text-white dark:focus:bg-green-500 dark:focus:text-white focus:outline-none"
    when "danger"
      "#{base_classes} text-gray-700 dark:text-gray-200 hover:bg-red-600 hover:text-white dark:hover:bg-red-500 dark:hover:text-white focus:bg-red-600 focus:text-white dark:focus:bg-red-500 dark:focus:text-white focus:outline-none"
    when "secondary"
      "#{base_classes} text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-600 hover:text-gray-900 dark:hover:text-white focus:bg-gray-300 dark:focus:bg-gray-500 focus:text-gray-900 dark:focus:text-white focus:outline-none"
    else
      "#{base_classes} text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white focus:bg-gray-200 dark:focus:bg-gray-600 focus:text-gray-900 dark:focus:text-white focus:outline-none"
    end
  end

  def item_icon_classes
    base_classes = "mr-3 h-4 w-4"

    case options[:hover_color]
    when "primary"
      "#{base_classes} text-gray-400 dark:text-gray-500 group-hover:text-white dark:group-hover:text-white group-focus:text-white dark:group-focus:text-white"
    when "success"
      "#{base_classes} text-gray-400 dark:text-gray-500 group-hover:text-white dark:group-hover:text-white group-focus:text-white dark:group-focus:text-white"
    when "danger"
      "#{base_classes} text-gray-400 dark:text-gray-500 group-hover:text-white dark:group-hover:text-white group-focus:text-white dark:group-focus:text-white"
    when "secondary"
      "#{base_classes} text-gray-400 dark:text-gray-500 group-hover:text-gray-900 dark:group-hover:text-white group-focus:text-gray-900 dark:group-focus:text-white"
    else
      "#{base_classes} text-gray-400 dark:text-gray-500 group-hover:text-gray-500 dark:group-hover:text-gray-400 group-focus:text-gray-500 dark:group-focus:text-gray-400"
    end
  end

  def disabled_button_classes
    "group flex items-center px-4 py-2 text-sm w-full text-left border-0 bg-transparent text-gray-400 dark:text-gray-500 cursor-not-allowed opacity-60"
  end

  def enabled_button_classes
    "#{item_hover_classes} w-full text-left border-0 bg-transparent"
  end

  def disabled_icon_classes
    "mr-3 h-4 w-4 text-gray-300 dark:text-gray-600"
  end
end
