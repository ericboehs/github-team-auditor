require "test_helper"

class SortableHelperUnitTest < ActiveSupport::TestCase
  include SortableHelper

  def setup
    @mock_controller = Object.new
    def @mock_controller.sort_column; @sort_column; end
    def @mock_controller.sort_direction; @sort_direction || "asc"; end
    def @mock_controller.set_sort(column, direction); @sort_column = column; @sort_direction = direction; end
  end

  def controller
    @mock_controller
  end

  test "next_sort_direction with no current sort" do
    @mock_controller.set_sort(nil, "asc")
    assert_equal "asc", next_sort_direction("name")
  end

  test "next_sort_direction with current column asc" do
    @mock_controller.set_sort("name", "asc")
    assert_equal "desc", next_sort_direction("name")
  end

  test "next_sort_direction with current column desc" do
    @mock_controller.set_sort("name", "desc")
    assert_equal "asc", next_sort_direction("name")
  end

  test "next_sort_direction with different column" do
    @mock_controller.set_sort("name", "desc")
    assert_equal "asc", next_sort_direction("status")
  end

  # These methods are now delegated to controller, tested in sorting_logic_test.rb

  test "sort_link handles url generation error gracefully" do
    @mock_controller.set_sort(nil, "asc")
    def url_for(options)
      raise ActionController::UrlGenerationError, "No route matches"
    end
    def content_tag(tag, content, options = {})
      "<#{tag} class='#{options[:class]}'>#{content}</#{tag}>"
    end

    result = sort_link("member", "Member")
    assert_includes result, "Member"
    assert_includes result, "span"
  end

  test "sort_link generates proper link structure" do
    @mock_controller.set_sort(nil, "asc")
    def url_for(options)
      "/test?#{options.to_query}"
    end
    def link_to(url, options = {})
      yield if block_given?
    end
    def content_tag(tag, content, options = {})
      content
    end

    result = sort_link("member", "Member")
    assert_includes result, "Member"
  end
end
