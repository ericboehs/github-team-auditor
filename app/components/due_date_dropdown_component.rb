class DueDateDropdownComponent < ViewComponent::Base
  def initialize(audit_session:, **options)
    @audit_session = audit_session
    @options = options
  end

  private

  attr_reader :audit_session, :options

  def button_text
    if audit_session.due_date
      content_tag(:span, class: "inline-flex items-center") do
        concat(calendar_icon)
        concat(content_tag(:span, formatted_due_date, class: "hidden sm:inline"))
        concat(content_tag(:span, formatted_due_date, class: "sm:hidden"))
      end
    else
      content_tag(:span, class: "inline-flex items-center") do
        concat(calendar_icon)
        concat(content_tag(:span, t("due_date.set_due_date"), class: "hidden sm:inline"))
        concat(content_tag(:span, t("common.due_date"), class: "sm:hidden"))
      end
    end
  end

  def formatted_due_date
    if audit_session.due_date.year == Date.current.year
      audit_session.due_date.strftime("%b %d")
    else
      audit_session.due_date.strftime("%b %d, %Y")
    end
  end

  def calendar_icon
    content_tag(:svg, class: "-ml-1 mr-2 h-4 w-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, "", "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z")
    end
  end

  def clear_icon
    content_tag(:svg, class: "h-4 w-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, "", "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M6 18L18 6M6 6l12 12")
    end
  end
end
