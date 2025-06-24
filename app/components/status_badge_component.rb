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
end
