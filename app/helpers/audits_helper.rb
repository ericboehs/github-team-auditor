module AuditsHelper
  def safe_github_link(member)
    return member.display_name unless member.github_url.present?

    # Validate the URL is actually a GitHub URL
    url = member.github_url
    return member.display_name unless url&.start_with?("https://github.com/")

    link_to member.display_name, url, target: "_blank",
            "aria-label": t("aria_labels.view_github_profile", name: member.display_name),
            class: "text-blue-800 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300"
  end
end
