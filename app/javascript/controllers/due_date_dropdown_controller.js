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

    // Add mobile-specific event handlers
    this.handleDateFieldInteraction = this.handleDateFieldInteraction.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleIOSDateInput = this.handleIOSDateInput.bind(this)

    // Detect iOS
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)


    if (this.hasDateFieldTarget) {
      // Prevent dropdown from closing when interacting with date field on mobile
      this.dateFieldTarget.addEventListener('focus', this.handleDateFieldInteraction)
      this.dateFieldTarget.addEventListener('click', this.handleDateFieldInteraction)
      this.dateFieldTarget.addEventListener('change', this.handleIOSDateInput)

      // iOS-specific: lighter touch approach
      if (this.isIOS) {
        this.dateFieldTarget.addEventListener('input', this.handleIOSDateInput)
        // Monitor for when the date picker opens/closes
        this.dateFieldTarget.addEventListener('blur', this.handleDateFieldBlur.bind(this))
      }
    }

    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this.handleFormSubmit)
    }
  }

  disconnect() {
    if (this.hasDateFieldTarget) {
      this.dateFieldTarget.removeEventListener('focus', this.handleDateFieldInteraction)
      this.dateFieldTarget.removeEventListener('click', this.handleDateFieldInteraction)
      this.dateFieldTarget.removeEventListener('change', this.handleIOSDateInput)

      if (this.isIOS) {
        this.dateFieldTarget.removeEventListener('input', this.handleIOSDateInput)
        this.dateFieldTarget.removeEventListener('blur', this.handleDateFieldBlur)
      }
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

      // Re-enable after a longer delay for iOS to allow for date picker interactions
      const delay = this.isIOS ? 2000 : 500
      this.dropdownController.dateFieldTimeout = setTimeout(() => {
        if (this.dropdownController) {
          this.dropdownController.dateFieldActive = false
          this.dropdownController.dateFieldTimeout = null
        }
      }, delay)
    }
  }

  handleIOSDateInput(event) {
    // iOS-specific handler for date input events
    if (!this.isIOS) return

    // Prevent any event that might close the dropdown
    event.stopPropagation()

    // Keep the dropdown protection active during iOS date picking
    if (this.dropdownController) {
      this.dropdownController.dateFieldActive = true

      // Clear existing timeout and set a new one
      if (this.dropdownController.dateFieldTimeout) {
        clearTimeout(this.dropdownController.dateFieldTimeout)
      }

      // Extended timeout for iOS date picker interactions
      this.dropdownController.dateFieldTimeout = setTimeout(() => {
        if (this.dropdownController) {
          this.dropdownController.dateFieldActive = false
          this.dropdownController.dateFieldTimeout = null
        }
      }, 1500)
    }
  }

  handleDateFieldBlur(event) {
    // Handle blur events from the date field on iOS
    if (!this.isIOS) return

    // When the date field loses focus, give a short grace period
    // before allowing dropdown to close again
    if (this.dropdownController) {
      this.dropdownController.dateFieldActive = true

      // Clear existing timeout
      if (this.dropdownController.dateFieldTimeout) {
        clearTimeout(this.dropdownController.dateFieldTimeout)
      }

      // Short timeout to allow user to interact with Save/Cancel buttons
      this.dropdownController.dateFieldTimeout = setTimeout(() => {
        if (this.dropdownController) {
          this.dropdownController.dateFieldActive = false
          this.dropdownController.dateFieldTimeout = null
        }
      }, 300)
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
