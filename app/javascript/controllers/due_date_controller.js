import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="due-date"
export default class extends Controller {
  static targets = ["form", "field", "clearButton"]

  toggleForm() {
    this.formTarget.classList.toggle('hidden')
  }

  clearDate() {
    this.fieldTarget.value = ''
    this.toggleClearButton()
  }

  toggleClearButton() {
    if (this.fieldTarget.value) {
      this.clearButtonTarget.classList.remove('hidden')
    } else {
      this.clearButtonTarget.classList.add('hidden')
    }
  }
}
