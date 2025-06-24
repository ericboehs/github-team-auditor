# frozen_string_literal: true

class StatsCardComponent < ViewComponent::Base
  def initialize(title:, value:, icon_path:, icon_bg_color: "bg-emerald-100 dark:bg-emerald-900", icon_color: "text-emerald-600 dark:text-emerald-400", **options)
    @title = title
    @value = value
    @icon_path = icon_path
    @icon_bg_color = icon_bg_color
    @icon_color = icon_color
    @options = options
  end

  private

  attr_reader :title, :value, :icon_path, :icon_bg_color, :icon_color, :options

  def card_classes
    base_classes = "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg"
    extra_classes = options[:class] || ""
    [ base_classes, extra_classes ].join(" ").strip
  end
end
