import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = { dismissUrl: String }

  dismiss() {
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

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
