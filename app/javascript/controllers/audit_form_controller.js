import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["teamSelect"]

  connect() {
    // Clear team select on page load if no organization selected
    if (!this.element.querySelector("#audit_session_organization_id").value) {
      this.clearTeams()
    }
  }

  loadTeams(event) {
    const organizationId = event.target.value
    const teamSelect = this.teamSelectTarget

    if (!organizationId) {
      this.clearTeams()
      return
    }

    // For now, we'll use the existing teams in fixtures
    // In a real app, this would make an AJAX call to fetch teams
    this.populateTeamsBasedOnOrganization(organizationId, teamSelect)
  }

  clearTeams() {
    const teamSelect = this.teamSelectTarget
    teamSelect.innerHTML = `<option value="">${teamSelect.dataset.placeholder}</option>`
    teamSelect.disabled = true
  }

  populateTeamsBasedOnOrganization(organizationId, teamSelect) {
    // Clear existing options
    teamSelect.innerHTML = `<option value="">${teamSelect.dataset.placeholder}</option>`

    // TODO: Implement AJAX call to fetch teams for the selected organization
    // For now, teams are loaded via the Rails form helper

    teamSelect.disabled = true
  }
}
