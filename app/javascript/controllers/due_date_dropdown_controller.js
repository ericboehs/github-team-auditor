import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="due-date-dropdown"
export default class extends Controller {
  static targets = ["form", "dateField"]

  clearDate() {
    // Set the date field to empty
    this.dateFieldTarget.value = ""

    // Submit the form to clear the due date
    this.formTarget.submit()
  }
}
