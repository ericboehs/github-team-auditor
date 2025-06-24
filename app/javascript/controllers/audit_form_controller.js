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
    teamSelect.innerHTML = '<option value="">Select a team</option>'
    teamSelect.disabled = true
  }

  populateTeamsBasedOnOrganization(organizationId, teamSelect) {
    // Clear existing options
    teamSelect.innerHTML = '<option value="">Select a team</option>'

    // This is a simplified version - in production you'd fetch via AJAX
    const teams = {
      "34184513": [ // Department of Veterans Affairs
        { id: "15455700", name: "Platform Security", slug: "platform-security" },
        { id: "259099539", name: "Backend Tools", slug: "backend-tools" }
      ]
    }

    const orgTeams = teams[organizationId] || []

    orgTeams.forEach(team => {
      const option = document.createElement('option')
      option.value = team.id
      option.textContent = `${team.name} (${team.slug})`
      teamSelect.appendChild(option)
    })

    teamSelect.disabled = orgTeams.length === 0
  }
}
