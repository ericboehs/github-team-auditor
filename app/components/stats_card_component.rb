# frozen_string_literal: true

class StatsCardComponent < ViewComponent::Base
  def initialize(title:, value:, icon_path:, icon_color: "text-blue-800 dark:text-blue-400", url: nil, **options)
    @title = title
    @value = value
    @icon_path = icon_path
    @icon_color = icon_color
    @url = url
    @options = options
  end

  private

  attr_reader :title, :value, :icon_path, :icon_color, :url, :options

  def card_classes
    base_classes = "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg"
    extra_classes = options[:class] || ""
    [ base_classes, extra_classes ].join(" ").strip
  end
end
