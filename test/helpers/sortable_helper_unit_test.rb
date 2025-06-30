require "test_helper"

class SortableHelperUnitTest < ActiveSupport::TestCase
  include SortableHelper

  def setup
    @mock_controller = Object.new
    def @mock_controller.sort_column; @sort_column; end
    def @mock_controller.sort_direction; @sort_direction || "asc"; end
    def @mock_controller.effective_sort_column_for_team_members; @sort_column || "github"; end
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

  test "sort_link adds active styling for current column" do
    @mock_controller.set_sort("member", "asc")
    def url_for(options)
      "/test?#{options.to_query}"
    end
    def link_to(url, options = {})
      assert_includes options[:class], "text-gray-700 dark:text-gray-300"
      yield if block_given?
    end
    def content_tag(tag, content, options = {})
      content
    end

    result = sort_link("member", "Member")
    assert_includes result, "Member"
  end

  test "sort_link shows up arrow for asc sort" do
    @mock_controller.set_sort("member", "asc")
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
    assert_includes result, "<svg"
    assert_includes result, "M14.77 12.79" # Up arrow path
  end

  test "sort_link shows down arrow for desc sort" do
    @mock_controller.set_sort("member", "desc")
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
    assert_includes result, "<svg"
    assert_includes result, "M5.23 7.21" # Down arrow path
  end

  test "chevron icon methods return SVG" do
    result = send(:chevron_up_icon)
    assert_includes result, "<svg"
    assert_includes result, "fill-rule"

    result = send(:chevron_down_icon)
    assert_includes result, "<svg"
    assert_includes result, "fill-rule"

    result = send(:chevron_up_down_icon)
    assert_includes result, "<svg"
    assert_includes result, "fill-rule"
  end

  test "team_member_sort_link defaults to github when no sort is set" do
    @mock_controller.set_sort(nil, "asc")
    def url_for(options)
      "/test?#{options.to_query}"
    end
    def link_to(url, options = {})
      # Should show active styling for github column since it's the default
      assert_includes options[:class], "text-gray-700 dark:text-gray-300"
      yield if block_given?
    end
    def content_tag(tag, content, options = {})
      content
    end

    result = team_member_sort_link("github", "GitHub")
    assert_includes result, "GitHub"
  end

  test "team_member_sort_link handles url generation error gracefully" do
    @mock_controller.set_sort(nil, "asc")
    def url_for(options)
      raise ActionController::UrlGenerationError, "No route matches"
    end
    def content_tag(tag, content, options = {})
      "<#{tag} class='#{options[:class]}'>#{content}</#{tag}>"
    end

    result = team_member_sort_link("member", "Member")
    assert_includes result, "Member"
    assert_includes result, "span"
  end

  test "team_member_sort_link shows active styling for effective column" do
    @mock_controller.set_sort("member", "desc")
    def url_for(options)
      "/test?#{options.to_query}"
    end
    def link_to(url, options = {})
      assert_includes options[:class], "text-gray-700 dark:text-gray-300"
      yield if block_given?
    end
    def content_tag(tag, content, options = {})
      content
    end

    result = team_member_sort_link("member", "Member")
    assert_includes result, "Member"
  end

  test "team_member_sort_link uses url_for when no id parameter present" do
    @mock_controller.set_sort("member", "desc")
    
    # Mock params to not include :id to trigger else branch (line 91)
    def params
      { sort: "member", direction: "desc" }  # No :id key
    end
    
    def url_for(options)
      # Should hit this path since no :id is present
      "/teams?#{options.to_query}"
    end
    
    def link_to(url, options = {})
      # Parameters might be in different order due to hash ordering
      assert_includes url, "sort=member"
      assert_includes url, "direction=asc"
      assert_includes url, "/teams?"
      yield if block_given?
    end
    
    def content_tag(tag, content, options = {})
      content
    end

    result = team_member_sort_link("member", "Member")
    assert_includes result, "Member"
  end
end
