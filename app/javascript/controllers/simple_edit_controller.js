import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "input"]
  static values = { id: String }

  edit() {
    this.displayTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      this.save()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  save() {
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

  cancel() {
    // Reset input to original value and switch back
    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }
}
