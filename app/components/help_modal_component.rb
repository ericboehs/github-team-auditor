# frozen_string_literal: true

class HelpModalComponent < ViewComponent::Base
  def initialize(**options)
    @options = options
  end

  private

  attr_reader :options

  def modal_classes
    extra_classes = options.delete(:class) || ""
    "fixed inset-0 z-50 overflow-y-auto #{extra_classes}".strip
  end
end
