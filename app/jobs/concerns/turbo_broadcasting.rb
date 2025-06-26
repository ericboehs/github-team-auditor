module TurboBroadcasting
  extend ActiveSupport::Concern

  private

  def broadcast_job_started(team, message_key, announcement_key)
    # Broadcast job started status banner
    broadcast_status_banner(team, I18n.t(message_key), :info, spinner: true)

    # Announce start to screen readers
    broadcast_live_announcement(team, I18n.t(announcement_key, team_name: team.name))

    # Update team card on index page to show job running state
    broadcast_team_card_update(team)
  end

  def broadcast_job_completed(team, message, type: :success)
    # Broadcast completion message
    broadcast_flash_message(team, message, type)

    # Clear status banner
    broadcast_clear_status_banner(team)

    # Update team actions dropdown to re-enable buttons
    broadcast_dropdown_update(team)

    # Update team card on index page to remove job status
    broadcast_team_card_update(team)
  end

  def broadcast_job_error(team, error)
    return unless team

    # Create user-friendly error message
    friendly_message = translate_error_message(error)

    # Broadcast error message
    broadcast_flash_message(team, friendly_message, :alert)

    # Announce error to screen readers
    broadcast_live_announcement(team, I18n.t("jobs.shared.error_announcement", team_name: team.name, message: friendly_message))

    # Clear status banner and update dropdown
    broadcast_clear_status_banner(team)
    broadcast_dropdown_update(team)
  end

  def broadcast_status_banner(team, message, type, spinner: false)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "status-banner-container",
      partial: "shared/status_banner",
      locals: { message: message, type: type, spinner: spinner }
    )
  end

  def broadcast_flash_message(team, message, type)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "flash-messages",
      partial: "shared/turbo_flash_message",
      locals: { message: message, type: type }
    )
  end

  def broadcast_live_announcement(team, announcement)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "live-announcements",
      html: announcement
    )
  end

  def broadcast_clear_status_banner(team)
    Turbo::StreamsChannel.broadcast_update_to(
      "team_#{team.id}",
      target: "status-banner-container",
      html: ""
    )
  end

  def broadcast_dropdown_update(team)
    Turbo::StreamsChannel.broadcast_replace_to(
      "team_#{team.id}",
      target: "team-actions-dropdown",
      partial: "teams/team_actions_dropdown",
      locals: { team: team }
    )
  end

  def broadcast_team_card_update(team)
    team.reload # Ensure fresh data
    Turbo::StreamsChannel.broadcast_replace_to(
      "teams_index",
      target: "team-card-#{team.id}",
      partial: "teams/team_card",
      locals: { team: team }
    )
  end

  def translate_error_message(error)
    case error.class.name
    when "Github::ApiClient::ConfigurationError"
      I18n.t("jobs.shared.errors.configuration")
    when "Octokit::Unauthorized"
      I18n.t("jobs.shared.errors.unauthorized")
    when "Octokit::TooManyRequests"
      I18n.t("jobs.shared.errors.rate_limit")
    when "Octokit::NetworkError", "Net::TimeoutError", "Errno::ECONNREFUSED"
      I18n.t("jobs.shared.errors.network")
    else
      I18n.t("jobs.shared.errors.unexpected")
    end
  end
end
