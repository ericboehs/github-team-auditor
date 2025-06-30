import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  // Much simpler now - Turbo handles the updates!
  connect() {
    // Just ensure proper focus behavior after Turbo frame updates
    this.element.addEventListener('turbo:frame-load', this.handleFrameLoad.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('turbo:frame-load', this.handleFrameLoad.bind(this))
  }

  handleFrameLoad(event) {
    // After Turbo updates the frame, restore focus to maintain keyboard navigation
    const navController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="keyboard-navigation"]'),
      'keyboard-navigation'
    )

    if (navController && navController.currentItemIndex !== null) {
      // Re-initialize the keyboard navigation after the table updates
      setTimeout(() => {
        const actionableItems = navController.actionableTargets
        if (actionableItems.length > 0) {
          // Focus on the first item or maintain relative position
          const targetIndex = Math.min(navController.currentItemIndex, actionableItems.length - 1)
          actionableItems[targetIndex].focus()
          navController.currentItemIndex = targetIndex
        }
      }, 50)
    }
  }
}
