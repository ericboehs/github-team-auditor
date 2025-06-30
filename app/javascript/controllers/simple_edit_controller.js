import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "input"]
  static values = { id: String }

  connect() {
    this.isCanceling = false
  }

  edit() {
    this.isCanceling = false
    this.displayTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  handleKeydown(event) {
    // If we're in the input field
    if (event.target === this.inputTarget) {
      if (event.key === "Enter") {
        if (event.ctrlKey) {
          // Ctrl+Enter: Save and stay in place
          this.saveAndStay()
        } else if (event.shiftKey) {
          // Shift+Enter: Save and go to cell above
          this.saveAndMoveUp()
        } else {
          // Enter: Save and go to cell below
          this.saveAndMoveDown()
        }
      } else if (event.key === "Escape") {
        this.isCanceling = true
        this.cancel()
      }
    }
    // If we're on the display element and Enter is pressed, start editing
    else if (event.target === this.displayTarget && event.key === "Enter") {
      event.preventDefault()
      this.edit()
    }
  }

  save(onSuccess = null) {
    // Don't save if we're canceling
    if (this.isCanceling) {
      this.isCanceling = false
      return
    }

    const value = this.inputTarget.value.trim()

    // Send AJAX request to save the value
    fetch(`/audit_members/${this.idValue}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        audit_member: {
          notes: value
        }
      })
    })
    .then(response => {
      if (response.ok) {
        // Update display text and switch back
        this.displayTarget.textContent = value || "None"

        // Update CSS classes based on whether there's content
        if (value) {
          this.displayTarget.classList.remove("text-gray-400", "dark:text-gray-500")
          this.displayTarget.classList.add("text-gray-500", "dark:text-gray-400")
        } else {
          this.displayTarget.classList.remove("text-gray-500", "dark:text-gray-400")
          this.displayTarget.classList.add("text-gray-400", "dark:text-gray-500")
        }

        this.inputTarget.classList.add("hidden")
        this.displayTarget.classList.remove("hidden")

        // Call the success callback if provided, after UI updates are complete
        if (onSuccess) {
          setTimeout(() => {
            onSuccess()
          }, 0)
        }
      } else {
        console.error('Failed to save note')
        this.cancel()
      }
    })
    .catch(error => {
      console.error('Error saving note:', error)
      this.cancel()
    })
  }

  saveAndStay() {
    this.save(() => {
      this.displayTarget.focus()
    })
  }

  saveAndMoveDown() {
    this.save(() => {
      this.moveToNextCell('down')
    })
  }

  saveAndMoveUp() {
    this.save(() => {
      this.moveToNextCell('up')
    })
  }

  moveToNextCell(direction) {
    // Find the keyboard navigation controller
    const navController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="keyboard-navigation"]'),
      'keyboard-navigation'
    )

    if (navController) {
      // Get current position
      const currentItem = this.displayTarget
      const currentColumn = navController.getColumnIndex(currentItem)
      const currentRow = navController.getRowIndex(currentItem)

      // Find target row
      const targetRow = direction === 'down' ? currentRow + 1 : currentRow - 1
      const targetItem = navController.findItemInColumn(currentColumn, targetRow)

      if (targetItem) {
        // Update navigation controller's current index
        const targetIndex = navController.actionableTargets.indexOf(targetItem)
        if (targetIndex !== -1) {
          navController.currentItemIndex = targetIndex

          // If the target is a comment field, start editing directly without focusing first
          if (targetItem.hasAttribute('data-simple-edit-target') &&
              targetItem.getAttribute('data-simple-edit-target') === 'display') {
            // Find the simple-edit controller for this element
            const editController = this.application.getControllerForElementAndIdentifier(
              targetItem.closest('[data-controller*="simple-edit"]'),
              'simple-edit'
            )
            if (editController) {
              // Use setTimeout to ensure the current save operation's UI updates are complete
              setTimeout(() => {
                editController.edit()
              }, 0)
            }
          } else {
            // Only focus if we're not going to start editing
            targetItem.focus()
          }
        }
      }
    }
  }

  cancel() {
    // Don't reset input value - preserve it for next edit
    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
    this.displayTarget.focus()
  }
}
