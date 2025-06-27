module TeamsHelper
  def sync_button_classes(team)
    base_classes = "flex items-center justify-center w-full px-2 sm:px-3 py-2 text-xs sm:text-sm font-medium rounded-md shadow-xs focus:outline-none focus:ring-2 ring-1 ring-inset"

    if team.any_jobs_running?
      # Disabled state
      "#{base_classes} bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 ring-gray-300 dark:ring-gray-600 cursor-not-allowed opacity-60"
    else
      # Enabled state
      "#{base_classes} bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 focus:ring-blue-500"
    end
  end

  def sync_icon_classes(team)
    base_classes = "h-4 w-4"

    if team.any_jobs_running?
      "#{base_classes} text-gray-400 dark:text-gray-500"
    else
      "#{base_classes} text-gray-500 dark:text-gray-400"
    end
  end

  def team_actions_dropdown_items(team)
    [
      # Section 1: Primary action - New Audit
      {
        type: :link,
        text: t("teams.show.new_audit"),
        url: new_audit_path(team_id: team.id),
        icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>',
        hover_color: "primary"
      },
      {
        type: :link,
        text: t("teams.actions.view_audits"),
        url: audits_path(team_id: team.id),
        icon_path: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.666 3.888A2.25 2.25 0 0 0 13.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 0 1-.75.75H9a.75.75 0 0 1-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 0 1-2.25 2.25H6.75A2.25 2.25 0 0 1 4.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 0 1 1.927-.184"/>',
        hover_color: "primary"
      },
      # Divider
      { type: :divider },
      # Section 2: GitHub operations
      {
        type: :link,
        text: t("teams.actions.view_on_github"),
        url: team.github_url,
        target: "_blank",
        icon_path: '<path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/>',
        hover_color: "secondary"
      },
      # Divider
      { type: :divider },
      # Section 3: Management actions
      {
        type: :link,
        text: t("buttons.edit"),
        url: edit_team_path(team),
        icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />',
        hover_color: "secondary"
      },
      {
        type: :form,
        text: t("buttons.delete"),
        url: team_path(team),
        method: :delete,
        data: { turbo_method: :delete, turbo_confirm: t("teams.form.delete_confirm") },
        icon_path: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />',
        hover_color: "danger"
      }
    ]
  end
end
