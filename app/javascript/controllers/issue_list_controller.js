import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summary", "expanded", "toggleButton"]

  toggle() {
    const isExpanded = !this.expandedTarget.hidden

    if (isExpanded) {
      this.expandedTarget.hidden = true
      this.summaryTarget.hidden = false
      this.toggleButtonTarget.textContent = this.toggleButtonTarget.dataset.expandText
    } else {
      this.expandedTarget.hidden = false
      this.summaryTarget.hidden = true
      this.toggleButtonTarget.textContent = this.toggleButtonTarget.dataset.collapseText
    }
  }
}
