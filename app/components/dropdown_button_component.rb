class DropdownButtonComponent < ViewComponent::Base
  def initialize(text:, variant: :default, items: [], hide_chevron_on_mobile: false, **options)
    @text = text
    @variant = variant
    @items = items
    @hide_chevron_on_mobile = hide_chevron_on_mobile
    @options = options
  end

  private

  attr_reader :text, :variant, :items, :hide_chevron_on_mobile, :options

  def button_classes
    base_classes = "inline-flex w-full justify-center gap-x-1.5 rounded-md px-3 py-2 text-sm font-semibold shadow-xs ring-1 ring-inset"

    variant_classes = case variant
    when :default
      "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
    when :primary
      "bg-vads-primary dark:bg-vads-primary-dark text-white ring-vads-primary dark:ring-vads-primary-dark hover:bg-blue-700 dark:hover:bg-blue-500"
    when :secondary
      "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
    when :success
      "bg-vads-success dark:bg-vads-success-dark text-white ring-vads-success dark:ring-vads-success-dark hover:bg-green-500 dark:hover:bg-green-500"
    when :danger
      "bg-vads-error dark:bg-vads-error-dark text-white ring-vads-error dark:ring-vads-error-dark hover:bg-red-500 dark:hover:bg-red-500"
    else
      "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700"
    end

    "#{base_classes} #{variant_classes}"
  end

  def chevron_classes
    case variant
    when :primary, :success, :danger
      "-mr-1 size-5 text-white/70"
    else
      "-mr-1 size-5 text-gray-400"
    end
  end

  def render_menu_item(item, item_id)
    case item[:type]
    when :divider
      render_divider_item
    when :form
      render_form_item(item, item_id)
    else
      render_link_item(item, item_id)
    end
  end

  def render_link_item(item, item_id)
    link_classes = item_hover_classes(item)
    icon_classes = item_icon_classes(item)

    # Merge dropdown close action with any existing data actions
    link_data = (item[:data] || {}).merge({ action: "click->dropdown#closeAction" })

    link_to item[:url],
            class: link_classes,
            role: "menuitem",
            tabindex: "0",
            id: item_id,
            method: item[:method],
            target: item[:target],
            data: link_data do
      concat content_tag(:svg, item[:icon_path]&.html_safe, class: icon_classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "aria-hidden": "true", "data-slot": "icon")
      concat item[:text]
    end
  end

  def render_divider_item
    content_tag :div, class: "border-t border-gray-100 dark:border-gray-700" do
      # Empty divider
    end
  end

  def render_form_item(item, item_id)
    button_classes = item_hover_classes(item) + " w-full text-left border-0 bg-transparent"
    icon_classes = item_icon_classes(item)

    # Add flash message clearing for sync and find issues actions
    action_data = { action: "click->dropdown#closeAction" }
    if item[:url]&.include?("sync") || item[:url]&.include?("find_issue_correlations")
      action_data[:action] = "click->dropdown#closeAction click->dropdown#clearFlashMessages"
    end

    form_with url: item[:url],
              method: item[:method],
              local: true,
              data: item[:data],
              class: "contents" do |form|
      content = ""

      # Add hidden field if specified
      if item[:hidden_field]
        content += form.hidden_field item[:hidden_field][:name], value: item[:hidden_field][:value]
      end

      content += form.button type: :submit,
                          class: button_classes,
                          role: "menuitem",
                          tabindex: "0",
                          id: item_id,
                          disabled: item[:disabled],
                          data: action_data do
        concat content_tag(:svg, item[:icon_path]&.html_safe, class: icon_classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "aria-hidden": "true", "data-slot": "icon")
        concat item[:text]
      end

      content.html_safe
    end
  end

  private

  def item_hover_classes(item)
    base_classes = "group flex items-center px-4 py-2 text-sm"

    case item[:hover_color]
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

  def item_icon_classes(item)
    base_classes = "mr-3 h-4 w-4"

    case item[:hover_color]
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
end
