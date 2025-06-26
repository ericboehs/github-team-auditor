class DropdownButtonComponent < ViewComponent::Base
  def initialize(text:, variant: :default, items: [], hide_chevron_on_mobile: false, **options)
    @text = text
    @variant = variant
    @items = items
    @hide_chevron_on_mobile = hide_chevron_on_mobile
    @options = options
  end

  private

  attr_reader :text, :variant, :items, :hide_chevron_on_mobile, :options

  def button_component
    Dropdown::ButtonComponent.new(
      text: text,
      variant: variant,
      hide_chevron_on_mobile: hide_chevron_on_mobile,
      **options
    )
  end

  def menu_component
    Dropdown::MenuComponent.new(
      items: items,
      **options
    )
  end
end
