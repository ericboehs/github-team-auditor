module SortableHelper
  # Delegate to controller's Sortable concern methods
  delegate :sort_column, :sort_direction, to: :controller

  def next_sort_direction(current_column)
    if sort_column == current_column
      sort_direction == "asc" ? "desc" : "asc"
    else
      "asc"
    end
  end

  def sort_link(column, title, path_params = {})
    direction = next_sort_direction(column)
    css_class = "group inline-flex items-center space-x-1 text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider hover:text-gray-700 dark:hover:text-gray-300"

    # Add active styling if this is the current sort column
    if sort_column == column
      css_class += " text-gray-700 dark:text-gray-300"
    end

    begin
      # Convert path_params to permitted hash and merge sort params
      permitted_params = path_params.respond_to?(:permit) ? path_params.to_unsafe_h : path_params
      link_params = permitted_params.merge(sort: column, direction: direction)

      link_to(url_for(link_params),
              class: css_class,
              data: { turbo_frame: "sortable-table" }) do
        content = title.dup

        # Add sort indicator
        if sort_column == column
          if sort_direction == "asc"
            content += " " + chevron_up_icon
          else
            content += " " + chevron_down_icon
          end
        else
          content += " " + chevron_up_down_icon
        end

        content.html_safe
      end
    rescue ActionController::UrlGenerationError, NoMethodError
      # Fallback when no route context (e.g., in job context)
      content_tag(:span, title, class: "text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider")
    end
  end

  private

  def chevron_up_icon
    <<~SVG.strip.html_safe
      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06-.02L10 8.832 6.29 12.77a.75.75 0 11-1.08-1.04l4.25-4.5a.75.75 0 011.08 0l4.25 4.5a.75.75 0 01-.02 1.06z" clip-rule="evenodd" />
      </svg>
    SVG
  end

  def chevron_down_icon
    <<~SVG.strip.html_safe
      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
      </svg>
    SVG
  end

  def chevron_up_down_icon
    <<~SVG.strip.html_safe
      <svg class="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 3a.75.75 0 01.55.24l3.25 3.5a.75.75 0 11-1.1 1.02L10 4.852 7.3 7.76a.75.75 0 01-1.1-1.02l3.25-3.5A.75.75 0 0110 3zm-3.76 9.2a.75.75 0 011.06.04l2.7 2.908 2.7-2.908a.75.75 0 111.1 1.02l-3.25 3.5a.75.75 0 01-1.1 0l-3.25-3.5a.75.75 0 01.04-1.06z" clip-rule="evenodd" />
      </svg>
    SVG
  end
end
