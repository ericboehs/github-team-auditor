import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="due-date-dropdown"
export default class extends Controller {
  static targets = ["form", "dateField"]

  connect() {
    // Get the dropdown controller for this element
    this.dropdownController = this.application.getControllerForElementAndIdentifier(
      this.element,
      'dropdown'
    )

    if (this.hasDateFieldTarget) {
      // Prevent dropdown from closing when interacting with date field
      this.dateFieldTarget.addEventListener('focus', this.handleDateFieldInteraction.bind(this))
      this.dateFieldTarget.addEventListener('click', this.handleDateFieldInteraction.bind(this))
      this.dateFieldTarget.addEventListener('change', this.handleDateFieldInteraction.bind(this))
    }

    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this.handleFormSubmit.bind(this))
    }
  }

  disconnect() {
    if (this.hasDateFieldTarget) {
      this.dateFieldTarget.removeEventListener('focus', this.handleDateFieldInteraction)
      this.dateFieldTarget.removeEventListener('click', this.handleDateFieldInteraction)
      this.dateFieldTarget.removeEventListener('change', this.handleDateFieldInteraction)
    }

    if (this.hasFormTarget) {
      this.formTarget.removeEventListener('submit', this.handleFormSubmit)
    }
  }

  handleDateFieldInteraction(event) {
    // Prevent the dropdown from closing when interacting with the date field
    event.stopPropagation()

    // Temporarily disable the dropdown's close-on-focus-out behavior
    if (this.dropdownController) {
      this.dropdownController.dateFieldActive = true

      // Clear any existing timeout
      if (this.dropdownController.dateFieldTimeout) {
        clearTimeout(this.dropdownController.dateFieldTimeout)
      }

      // Re-enable after a short delay to allow for date picker interactions
      this.dropdownController.dateFieldTimeout = setTimeout(() => {
        if (this.dropdownController) {
          this.dropdownController.dateFieldActive = false
          this.dropdownController.dateFieldTimeout = null
        }
      }, 1000)
    }
  }

  handleFormSubmit(event) {
    // Close the dropdown after form submission
    setTimeout(() => {
      if (this.dropdownController && this.dropdownController.isOpen()) {
        this.dropdownController.closeMenu()
      }
    }, 100)
  }

  clearDate() {
    // Set the date field to empty
    this.dateFieldTarget.value = ""

    // Submit the form to clear the due date
    this.formTarget.submit()
  }
}
