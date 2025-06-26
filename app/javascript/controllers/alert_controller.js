import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = { dismissUrl: String }

  connect() {
    this.dismissed = false
    // Add mobile-friendly event listeners as backup
    const dismissButton = this.element.querySelector('[data-action*="alert#dismiss"]')
    if (dismissButton) {
      // Add touch listeners for mobile support
      dismissButton.addEventListener('touchend', this.handleTouch.bind(this), { passive: false })
    }
  }

  handleTouch(event) {
    if (this.dismissed) return
    event.preventDefault()
    event.stopPropagation()
    this.dismiss(event)
  }

  dismiss(event) {
    // Prevent duplicate dismissals
    if (this.dismissed) return
    this.dismissed = true

    // Prevent any default behavior
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    // Store reference to next focusable element before removal
    const nextFocusElement = this.findNextFocusElement()

    // Add closing animation
    this.element.style.transition = 'all 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'
    this.element.style.maxHeight = this.element.offsetHeight + 'px'

    // Wait a frame then collapse height
    requestAnimationFrame(() => {
      this.element.style.maxHeight = '0'
      this.element.style.marginBottom = '0'
      this.element.style.paddingTop = '0'
      this.element.style.paddingBottom = '0'
    })

    // If there's a custom dismiss URL, hit that endpoint
    if (this.dismissUrlValue) {
      fetch(this.dismissUrlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'X-Requested-With': 'XMLHttpRequest'
        }
      }).catch(() => {
        // Continue with removal even if request fails
      })
    }

    // Remove element after animation completes and manage focus
    setTimeout(() => {
      this.element.remove()
      // Return focus to next logical element
      if (nextFocusElement) {
        nextFocusElement.focus()
      }
    }, 300)
  }

  // Find the next logical element to focus after dismissing the alert
  findNextFocusElement() {
    // Try to find the main content area
    const mainContent = document.querySelector('main#main-content')
    if (mainContent) {
      // Look for the first focusable element in main content
      const focusableElements = mainContent.querySelectorAll(
        'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
      return focusableElements[0] || mainContent
    }

    // Fallback to skip link or body
    return document.querySelector('.skip-link') || document.body
  }
}
