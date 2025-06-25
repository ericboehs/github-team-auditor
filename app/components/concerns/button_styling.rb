# frozen_string_literal: true

module ButtonStyling
  extend ActiveSupport::Concern

  private

  def button_base_classes
    "rounded-md px-3 py-1.5 text-sm/6 font-semibold shadow-xs focus-visible:outline-2 focus-visible:outline-offset-2"
  end

  def button_variant_classes(variant)
    case variant
    when :primary
      "bg-emerald-600 dark:bg-emerald-500 text-white hover:bg-emerald-500 dark:hover:bg-emerald-400 focus-visible:outline-emerald-600 dark:focus-visible:outline-emerald-500"
    when :secondary
      "bg-white dark:bg-white/10 text-gray-900 dark:text-white ring-1 ring-gray-300 dark:ring-white/20 ring-inset hover:bg-gray-50 dark:hover:bg-white/20"
    when :danger
      "bg-red-600 dark:bg-red-700 text-white hover:bg-red-500 dark:hover:bg-red-600 focus-visible:outline-red-600 dark:focus-visible:outline-red-700"
    when :warning
      "bg-yellow-600 dark:bg-yellow-700 text-white hover:bg-yellow-500 dark:hover:bg-yellow-600 focus-visible:outline-yellow-600 dark:focus-visible:outline-yellow-700"
    when :success
      "bg-green-600 dark:bg-green-700 text-white hover:bg-green-500 dark:hover:bg-green-600 focus-visible:outline-green-600 dark:focus-visible:outline-green-700"
    else
      # Fallback to secondary variant for unknown variants
      "bg-white dark:bg-white/10 text-gray-900 dark:text-white ring-1 ring-gray-300 dark:ring-white/20 ring-inset hover:bg-gray-50 dark:hover:bg-white/20"
    end
  end

  def build_button_classes(variant:, extra_classes: "", include_flex: false)
    base = button_base_classes
    base = "inline-flex items-center #{base}" if include_flex

    variant_classes = button_variant_classes(variant)

    [ base, variant_classes, extra_classes ].join(" ").strip
  end
end
