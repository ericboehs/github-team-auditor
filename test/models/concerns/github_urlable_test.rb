# frozen_string_literal: true

require "test_helper"

# Test class to include the concern
class TestModelWithGithubUrlable < ApplicationRecord
  self.table_name = "team_members" # Use existing table that has github_login column
  include GithubUrlable
end

class GithubUrlableTest < ActiveSupport::TestCase
  setup do
    @model = TestModelWithGithubUrlable.new
    @model.team_id = teams(:platform_security).id # Need team_id for uniqueness validation
  end

  # Test github_url with blank github_login (missing branch coverage)
  test "github_url returns nil when github_login is blank" do
    @model.github_login = nil
    assert_nil @model.github_url

    @model.github_login = ""
    assert_nil @model.github_url

    @model.github_login = "   "
    assert_nil @model.github_url
  end

  test "github_url returns URL when github_login is present" do
    @model.github_login = "testuser"
    assert_equal "https://github.com/testuser", @model.github_url
  end

  test "github_url sanitizes invalid characters" do
    @model.github_login = "test@user!"
    assert_equal "https://github.com/testuser", @model.github_url
  end

  # Test display_name with blank name (missing branch coverage)
  test "display_name returns github_login when name is blank" do
    @model.github_login = "testuser"
    @model.name = nil
    assert_equal "testuser", @model.display_name

    @model.name = ""
    assert_equal "testuser", @model.display_name

    @model.name = "   "
    assert_equal "testuser", @model.display_name
  end

  test "display_name returns name when name is present" do
    @model.github_login = "testuser"
    @model.name = "Test User"
    assert_equal "Test User", @model.display_name
  end

  # Test validation
  test "validates github_login presence" do
    @model.github_login = nil
    refute @model.valid?
    assert_includes @model.errors[:github_login], "can't be blank"
  end

  test "validates github_login format" do
    @model.github_login = "invalid@login!"
    refute @model.valid?
    assert_includes @model.errors[:github_login], "can only contain letters, numbers, dashes, and underscores"

    @model.github_login = "valid-login_123"
    @model.valid? # This will trigger validation
    refute_includes @model.errors[:github_login], "can only contain letters, numbers, dashes, and underscores"
  end

  test "github_url handles empty string properly" do
    @model.github_login = ""
    assert_nil @model.github_url

    @model.github_login = "   "
    assert_nil @model.github_url
  end

  test "display_name handles empty string properly" do
    @model.github_login = "testuser"
    @model.name = ""
    assert_equal "testuser", @model.display_name

    @model.name = "   "
    assert_equal "testuser", @model.display_name
  end
end
