# frozen_string_literal: true

require "test_helper"

class DueDateDropdownComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  def setup
    @audit_session = audit_sessions(:q1_2025_audit)
  end

  def test_renders_set_due_date_when_no_date
    @audit_session.update!(due_date: nil)
    component = DueDateDropdownComponent.new(audit_session: @audit_session)
    render_inline(component)

    assert_selector "button", text: /Set Due Date/
    assert_selector "input[type='date']"
    assert_selector "button[type='submit']", text: "Save"
  end

  def test_renders_due_date_when_set
    due_date = Date.new(2024, 12, 25)
    @audit_session.update!(due_date: due_date)
    component = DueDateDropdownComponent.new(audit_session: @audit_session)
    render_inline(component)

    assert_selector "button", text: /Dec 25, 2024/
    assert_selector "input[type='date'][value='2024-12-25']"
    assert_selector "button", text: "Clear"
  end

  def test_form_submission_updates_due_date
    component = DueDateDropdownComponent.new(audit_session: @audit_session)
    render_inline(component)

    assert_selector "form[action='#{audit_path(@audit_session)}']"
    assert_selector "button[type='submit']", text: "Save"
  end
end
