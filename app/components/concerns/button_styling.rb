# frozen_string_literal: true

module ButtonStyling
  extend ActiveSupport::Concern

  private

  def button_base_classes
    "rounded-md px-3 py-1.5 text-sm/6 font-semibold shadow-xs focus-visible:outline-2 focus-visible:outline-offset-2"
  end

  def button_variant_classes(variant, disabled: false)
    if disabled
      "bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed opacity-60"
    else
      case variant
      when :primary
        "bg-vads-primary dark:bg-vads-primary-dark text-white hover:bg-blue-700 dark:hover:bg-blue-500 focus-visible:outline-vads-primary dark:focus-visible:outline-vads-primary-dark"
      when :secondary
        "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-1 ring-gray-300 dark:ring-gray-600 ring-inset hover:bg-gray-50 dark:hover:bg-gray-700"
      when :danger
        "bg-vads-error dark:bg-vads-error-dark text-white hover:bg-red-500 dark:hover:bg-red-500 focus-visible:outline-vads-error dark:focus-visible:outline-vads-error-dark"
      when :warning
        "bg-vads-warning dark:bg-vads-warning-dark text-yellow-900 dark:text-white hover:bg-yellow-300 dark:hover:bg-yellow-400 focus-visible:outline-vads-warning dark:focus-visible:outline-vads-warning-dark"
      when :success
        "bg-vads-success dark:bg-vads-success-dark text-white hover:bg-green-500 dark:hover:bg-green-500 focus-visible:outline-vads-success dark:focus-visible:outline-vads-success-dark"
      else
        # Fallback to secondary variant for unknown variants
        "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 ring-1 ring-gray-300 dark:ring-gray-600 ring-inset hover:bg-gray-50 dark:hover:bg-gray-700"
      end
    end
  end

  def build_button_classes(variant:, extra_classes: "", include_flex: false, disabled: false)
    base = button_base_classes
    base = "inline-flex items-center #{base}" if include_flex

    variant_classes = button_variant_classes(variant, disabled: disabled)

    [ base, variant_classes, extra_classes ].join(" ").strip
  end
end
