# frozen_string_literal: true

class StatusBadgeComponent < ViewComponent::Base
  def initialize(status:, **options)
    @status = status.to_s.downcase
    @options = options
  end

  private

  attr_reader :status, :options

  def badge_classes
    base_classes = "inline-flex px-2 py-1 text-xs font-semibold rounded-full"

    status_classes = case status
    when "active"
                      "bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-200"
    when "completed"
                      "bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-200"
    when "draft"
                      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-200"
    when "pending"
                      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-200"
    when "validated"
                      "bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-200"
    when "removed"
                      "bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-200"
    when "maintainer"
                      "bg-purple-100 text-purple-800 dark:bg-purple-600 dark:text-white"
    when "government"
                      "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-200"
    else
                      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    end

    extra_classes = options[:class] || ""

    [ base_classes, status_classes, extra_classes ].join(" ").strip
  end

  def status_text
    I18n.t("status_badges.#{status}", default: status.capitalize)
  end

  def status_icon
    case status
    when "active"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm3.857-9.809a.75.75 0 0 0-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 1 0-1.06 1.061l2.5 2.5a.75.75 0 0 0 1.137-.089l4-5.5Z" clip-rule="evenodd" />
      </svg>'
    when "completed"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd" />
      </svg>'
    when "draft", "pending"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
      </svg>'
    when "validated"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z" clip-rule="evenodd" />
      </svg>'
    when "removed"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
      </svg>'
    when "maintainer"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path d="M10 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM3.465 14.493a1.23 1.23 0 0 0 .41 1.412A9.957 9.957 0 0 0 10 18c2.31 0 4.438-.784 6.131-2.1.43-.333.604-.903.408-1.41a7.002 7.002 0 0 0-13.074.003Z" />
      </svg>'
    when "government"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M9.661 2.237a.531.531 0 0 1 .678 0 11.947 11.947 0 0 0 7.078 2.749.5.5 0 0 1 .479.425c.069.52.104 1.055.104 1.59 0 5.162-3.26 9.563-7.834 11.256a.48.48 0 0 1-.332 0C5.26 16.564 2 12.163 2 7c0-.535.035-1.07.104-1.589a.5.5 0 0 1 .48-.425 11.947 11.947 0 0 0 7.077-2.75ZM13 9a1 1 0 1 0-2 0v2a1 1 0 1 0 2 0V9Z" clip-rule="evenodd" />
      </svg>'
    else
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM9.555 7.168A1 1 0 0 0 8 8v4a1 1 0 0 0 1.555.832l3-2a1 1 0 0 0 0-1.664l-3-2Z" clip-rule="evenodd" />
      </svg>'
    end
  end
end
