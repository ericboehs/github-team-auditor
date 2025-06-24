module AuditsHelper
  def safe_github_link(member)
    return member.display_name unless member.github_url.present?

    # Validate the URL is actually a GitHub URL
    url = member.github_url
    return member.display_name unless url&.start_with?("https://github.com/")

    link_to member.display_name, url, target: "_blank",
            class: "text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300"
  end
end
