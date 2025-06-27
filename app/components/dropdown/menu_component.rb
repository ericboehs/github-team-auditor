class Dropdown::MenuComponent < ViewComponent::Base
  def initialize(items: [], **options)
    @items = items
    @options = options
  end

  private

  attr_reader :items, :options

  def menu_classes
    "absolute right-0 md:left-auto md:right-0 md:translate-x-0 z-10 mt-2 w-56 origin-top-right rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-hidden opacity-0 scale-95 transition ease-out duration-100 pointer-events-none"
  end


  def render_menu_item(item, item_id)
    case item[:type]
    when :divider
      render Dropdown::ItemComponent.new(type: :divider)
    when :form
      render Dropdown::ItemComponent.new(type: :form, **item, id: item_id)
    else
      render Dropdown::ItemComponent.new(type: :link, **item, id: item_id)
    end
  end
end
