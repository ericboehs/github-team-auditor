module ApplicationHelper
  def issue_status_icon(issue, css_classes = "h-4 w-4")
    if issue.resolved?
      # Purple check-circle for resolved issues
      content_tag(:svg, class: "#{css_classes} text-purple-600", fill: "none", stroke: "currentColor", "stroke-width": "1.5", viewBox: "0 0 24 24", "aria-hidden": "true") do
        tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z")
      end
    else
      # Green exclamation-circle for open issues
      content_tag(:svg, class: "#{css_classes} text-green-600", fill: "none", stroke: "currentColor", "stroke-width": "1.5", viewBox: "0 0 24 24", "aria-hidden": "true") do
        tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z")
      end
    end
  end
end
