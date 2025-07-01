import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  // Much simpler now - Turbo handles the updates!
  connect() {
    // Listen for turbo stream updates instead of frame loads
    document.addEventListener('turbo:before-stream-render', this.handleStreamRender.bind(this))

    // Listen for form submission to track when status toggle happens
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  disconnect() {
    document.removeEventListener('turbo:before-stream-render', this.handleStreamRender.bind(this))
    this.element.removeEventListener('submit', this.handleSubmit.bind(this))
  }

  handleSubmit(event) {
    // Store navigation context when form is submitted (status toggle)
    const navController = this.getNavigationController()
    if (navController && document.activeElement) {
      this.shouldAdvanceToNextRow = true
      this.storedColumnIndex = navController.getColumnIndex(document.activeElement)
      this.storedRowIndex = navController.getRowIndex(document.activeElement)
    }
  }


  handleStreamRender(event) {
    // After Turbo stream updates, restore focus to maintain keyboard navigation
    // Only handle if the stream is updating the sortable-table
    if (event.detail.render && event.detail.render.toString().includes('sortable-table')) {
      const navController = this.getNavigationController()

      if (navController && this.shouldAdvanceToNextRow) {
        // Auto-advance to next row after status toggle
        setTimeout(() => {
          this.advanceToNextRow(navController)
          this.shouldAdvanceToNextRow = false
        }, 50)
      } else if (navController && navController.currentItemIndex !== null) {
        // Re-initialize the keyboard navigation after the table updates
        setTimeout(() => {
          const visibleItems = navController.visibleActionableTargets
          if (visibleItems.length > 0) {
            // Focus on the first item or maintain relative position
            const targetIndex = Math.min(navController.currentItemIndex, visibleItems.length - 1)
            visibleItems[targetIndex].focus()
            navController.currentItemIndex = targetIndex
          }
        }, 50)
      }
    }
  }

  getNavigationController() {
    return this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="keyboard-navigation"]'),
      'keyboard-navigation'
    )
  }

  advanceToNextRow(navController) {
    const visibleItems = navController.visibleActionableTargets
    if (visibleItems.length === 0) return

    // Try to find the same column in the next row
    const targetItem = navController.findItemInColumn(this.storedColumnIndex, this.storedRowIndex + 1)

    if (targetItem && navController.isElementVisible(targetItem) && navController.isElementFocusable(targetItem)) {
      // Found item in next row, same column
      const targetIndex = visibleItems.indexOf(targetItem)
      if (targetIndex !== -1) {
        navController.currentItemIndex = targetIndex
        navController.currentIssueIndex = 0
        navController.focusCurrentItem()
        return
      }
    }

    // No next row available, stay on current item
    // Find the current status button in the updated table
    const currentStatusButton = visibleItems.find(item =>
      navController.getColumnIndex(item) === this.storedColumnIndex &&
      navController.getRowIndex(item) === this.storedRowIndex
    )

    if (currentStatusButton) {
      const targetIndex = visibleItems.indexOf(currentStatusButton)
      navController.currentItemIndex = targetIndex
      navController.currentIssueIndex = 0
      navController.focusCurrentItem()
    }
  }
}
