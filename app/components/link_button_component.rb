# frozen_string_literal: true

class LinkButtonComponent < ViewComponent::Base
  include ButtonStyling

  def initialize(text:, url:, variant: :primary, include_flex: true, **options)
    @text = text
    @url = url
    @variant = variant
    @include_flex = include_flex
    @options = options
  end

  private

  attr_reader :text, :url, :variant, :include_flex, :options

  def button_classes
    extra_classes = options.delete(:class) || ""
    build_button_classes(variant: variant, extra_classes: extra_classes, include_flex: include_flex)
  end
end
