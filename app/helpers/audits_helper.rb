module AuditsHelper
  def safe_github_link(member, text = nil)
    text ||= member.display_name
    return text unless member.github_url.present?

    # Validate the URL is actually a GitHub URL
    url = member.github_url
    return text unless url&.start_with?("https://github.com/")

    link_to text, url, target: "_blank",
            "aria-label": t("aria_labels.view_github_profile", name: member.display_name),
            class: "text-blue-800 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300",
            "data-keyboard-navigation-target": "actionable"
  end
end
