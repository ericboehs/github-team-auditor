import { Controller } from "@hotwired/stimulus"

// Generic toggle controller for showing/hiding elements
// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["toggleable", "field", "clearButton"]

  toggle() {
    this.toggleableTarget.classList.toggle('hidden')
  }

  clearField() {
    if (this.hasFieldTarget) {
      this.fieldTarget.value = ''
      this.toggleClearButton()
    }
  }

  toggleClearButton() {
    if (this.hasClearButtonTarget && this.hasFieldTarget) {
      if (this.fieldTarget.value) {
        this.clearButtonTarget.classList.remove('hidden')
      } else {
        this.clearButtonTarget.classList.add('hidden')
      }
    }
  }
}
