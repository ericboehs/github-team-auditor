import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop"]

  connect() {
    this.isVisible = false
  }

  show() {
    this.isVisible = true
    this.modalTarget.style.display = "block"

    // Focus the modal for accessibility
    this.modalTarget.focus()

    // Prevent body scroll when modal is open
    document.body.classList.add("overflow-hidden")
  }

  hide() {
    this.isVisible = false
    this.modalTarget.style.display = "none"

    // Restore body scroll
    document.body.classList.remove("overflow-hidden")
  }

  toggle() {
    if (this.isVisible) {
      this.hide()
    } else {
      this.show()
    }
  }

  handleKeydown(event) {
    // Close modal on Escape key
    if (event.key === "Escape" && this.isVisible) {
      event.preventDefault()
      this.hide()
    }
  }

  handleBackdropClick(event) {
    // Close modal when clicking on backdrop (not the modal content)
    if (event.target === this.backdropTarget) {
      this.hide()
    }
  }
}
