module TeamsHelper
  def sync_button_classes(team)
    base_classes = "inline-flex items-center px-3 py-2 text-sm font-medium rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"

    if team.any_jobs_running?
      # Disabled state
      "#{base_classes} bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed opacity-60"
    else
      # Enabled state
      "#{base_classes} bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 focus:ring-blue-500"
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
end
