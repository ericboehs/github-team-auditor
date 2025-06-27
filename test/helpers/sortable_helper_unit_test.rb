require "test_helper"

class SortableHelperUnitTest < ActiveSupport::TestCase
  include SortableHelper

  test "next_sort_direction with no current sort" do
    def params; {}; end
    assert_equal "asc", next_sort_direction("name")
  end

  test "next_sort_direction with current column asc" do
    def params; { sort: "name", direction: "asc" }; end
    assert_equal "desc", next_sort_direction("name")
  end

  test "next_sort_direction with current column desc" do
    def params; { sort: "name", direction: "desc" }; end
    assert_equal "asc", next_sort_direction("name")
  end

  test "next_sort_direction with different column" do
    def params; { sort: "name", direction: "desc" }; end
    assert_equal "asc", next_sort_direction("status")
  end

  # These methods are now delegated to controller, tested in sorting_logic_test.rb

  test "sort_link handles url generation error gracefully" do
    def params; {}; end
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
    def params; {}; end
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
