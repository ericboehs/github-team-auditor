class Dropdown::BaseComponent < ViewComponent::Base
  def initialize(**options)
    @options = options
  end

  private

  attr_reader :options

  def dropdown_data
    {
      controller: "dropdown",
      **options.fetch(:data, {})
    }
  end

  def dropdown_classes
    "relative inline-block text-left"
  end
end
