class LinkComponent < ViewComponent::Base
  def initialize(text:, url:, centered: true)
    @text = text
    @url = url
    @centered = centered
  end

  private

  attr_reader :text, :url, :centered

  def wrapper_classes
    base_classes = "text-sm"
    base_classes += " text-center" if centered
    base_classes
  end

  def link_classes
    "font-semibold text-vads-primary dark:text-vads-primary-dark hover:text-blue-700 dark:hover:text-blue-300"
  end
end
