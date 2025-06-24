# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  include ButtonStyling

  def initialize(text:, type: :submit, variant: :primary, include_flex: false, **options)
    @text = text
    @type = type
    @variant = variant
    @include_flex = include_flex
    @options = options
  end

  private

  attr_reader :text, :type, :variant, :include_flex, :options

  def button_classes
    extra_classes = options.delete(:class) || ""
    build_button_classes(variant: variant, extra_classes: extra_classes, include_flex: include_flex)
  end
end
