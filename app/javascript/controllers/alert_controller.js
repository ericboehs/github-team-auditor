import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {

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

    // Determine which element to animate (wrapper or alert itself)
    const parent = this.element.parentElement
    const elementToAnimate = (parent && parent.classList.contains('mb-4') && parent.children.length === 1)
      ? parent
      : this.element

    // Add closing animation
    this.element.style.transition = 'all 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'

    // Set initial height for smooth collapse
    elementToAnimate.style.maxHeight = elementToAnimate.offsetHeight + 'px'
    elementToAnimate.style.overflow = 'hidden'
    elementToAnimate.style.transition = 'all 0.3s ease-out'

    // Wait a frame then collapse height
    requestAnimationFrame(() => {
      elementToAnimate.style.maxHeight = '0'
      elementToAnimate.style.marginBottom = '0'
      elementToAnimate.style.paddingTop = '0'
      elementToAnimate.style.paddingBottom = '0'
    })


    // Remove element after animation completes and manage focus
    setTimeout(() => {
      // Check if parent is a wrapper div with mb-4 class
      const parent = this.element.parentElement
      if (parent && parent.classList.contains('mb-4') && parent.children.length === 1) {
        // Remove the wrapper div instead of just the alert
        parent.remove()
      } else {
        // Fallback to removing just the alert element
        this.element.remove()
      }
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
