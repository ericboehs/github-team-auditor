require "test_helper"

class Dropdown::BaseComponentTest < ViewComponent::TestCase
  test "renders dropdown container with data controller" do
    render_inline Dropdown::BaseComponent.new do
      "Content"
    end

    assert_selector "div.relative.inline-block.text-left[data-controller='dropdown']"
    assert_text "Content"
  end

  test "accepts additional options" do
    render_inline Dropdown::BaseComponent.new(class: "custom-class", id: "dropdown-1") do
      "Content"
    end

    assert_selector "div[data-controller='dropdown']"
  end
end
