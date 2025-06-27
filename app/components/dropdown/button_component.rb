class Dropdown::ButtonComponent < ViewComponent::Base
  def initialize(text:, variant: :default, hide_chevron_on_mobile: false, **options)
    @text = text
    @variant = variant
    @hide_chevron_on_mobile = hide_chevron_on_mobile
    @options = options
  end

  private

  attr_reader :text, :variant, :hide_chevron_on_mobile, :options

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

  def mobile_button_classes
    "flex items-center justify-center text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 focus:outline-none focus:text-gray-600 dark:focus:text-gray-300 p-2 md:hidden"
  end

  def desktop_button_classes
    "#{button_classes} !hidden md:!inline-flex"
  end
end
