require "test_helper"

class Dropdown::ItemComponentTest < ViewComponent::TestCase
  test "renders link item" do
    render_inline Dropdown::ItemComponent.new(
      type: :link,
      text: "Edit",
      url: "/edit",
      id: "edit-item"
    )

    assert_selector "a[href='/edit']", text: "Edit"
    assert_selector "a[role='menuitem']"
    assert_selector "a[id='edit-item']"
  end

  test "renders form item" do
    render_inline Dropdown::ItemComponent.new(
      type: :form,
      text: "Delete",
      url: "/delete",
      method: :delete,
      id: "delete-item"
    )

    assert_selector "form[action='/delete'][method='post']"
    assert_selector "button[type='submit']", text: "Delete"
    assert_selector "input[name='_method'][value='delete']", visible: false
  end

  test "renders disabled form item" do
    render_inline Dropdown::ItemComponent.new(
      type: :form,
      text: "Disabled Action",
      url: "/action",
      disabled: true,
      id: "disabled-item"
    )

    assert_selector "button[disabled]", text: "Disabled Action"
    assert_selector "button.cursor-not-allowed.opacity-60"
  end

  test "renders divider item" do
    render_inline Dropdown::ItemComponent.new(type: :divider)

    assert_selector "div.border-t.border-gray-100"
  end

  test "renders item with icon" do
    icon_path = '<path stroke-linecap="round" stroke-linejoin="round" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2V7z" />'

    render_inline Dropdown::ItemComponent.new(
      type: :link,
      text: "Download",
      url: "/download",
      icon_path: icon_path
    )

    assert_selector "a", text: "Download"
    assert_selector "svg[viewbox='0 0 24 24']"
    assert_selector "svg path"
  end

  test "renders item with hover color styling" do
    render_inline Dropdown::ItemComponent.new(
      type: :link,
      text: "Danger Action",
      url: "/danger",
      hover_color: "danger"
    )

    assert_selector "a.hover\\:bg-red-600"
  end

  test "doesn't render for invalid type" do
    render_inline Dropdown::ItemComponent.new(type: :invalid)

    assert_no_selector "*"
  end
end
