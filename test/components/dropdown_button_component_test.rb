require "test_helper"

class DropdownButtonComponentTest < ViewComponent::TestCase
  def test_renders_default_dropdown
    items = [
      {
        text: "Edit",
        url: "#",
        icon_path: '<path d="m5.433 13.917 1.262-3.155A4 4 0 0 1 7.58 9.42l6.92-6.918a2.121 2.121 0 0 1 3 3l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 0 1-.65-.65Z" />'
      }
    ]

    render_inline(DropdownButtonComponent.new(text: "Options", items: items))

    assert_selector "button", text: "Options"
    assert_selector "div[role='menu']"
    assert_selector "a[role='menuitem']", text: "Edit"
  end

  def test_renders_with_form_items
    items = [
      {
        type: :form,
        text: "Delete",
        url: "/items/1",
        method: :delete,
        data: { turbo_method: :delete, turbo_confirm: "Are you sure?" },
        icon_path: '<path d="M8.75 1A2.75 2.75 0 0 0 6 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 1 0 .23 1.482l.149-.022.841 10.518A2.75 2.75 0 0 0 7.596 19h4.807a2.75 2.75 0 0 0 2.742-2.53l.841-10.52.149.023a.75.75 0 0 0 .23-1.482A41.03 41.03 0 0 0 14 4.193V3.75A2.75 2.75 0 0 0 11.25 1h-2.5Z" />'
      }
    ]

    render_inline(DropdownButtonComponent.new(text: "Actions", items: items))

    assert_selector "form"
    assert_selector "button[type='submit']", text: "Delete"
  end

  def test_renders_different_variants
    items = [ { text: "Test", url: "#", icon_path: "" } ]

    render_inline(DropdownButtonComponent.new(text: "Primary", variant: :primary, items: items))
    assert_selector "button.bg-vads-primary"

    render_inline(DropdownButtonComponent.new(text: "Danger", variant: :danger, items: items))
    assert_selector "button.bg-vads-error"
  end

  def test_groups_items_correctly
    items = [
      { text: "Edit", url: "#", icon_path: "" },
      { type: :divider },
      { text: "Delete", url: "#", icon_path: "" }
    ]

    render_inline(DropdownButtonComponent.new(text: "Options", items: items))

    assert_selector "a[role='menuitem']", count: 2
    assert_selector "div.border-t", count: 1 # divider
  end
end
