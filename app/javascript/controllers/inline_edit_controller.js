import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "empty", "input", "text"]
  static values = { id: String }

  edit() {
    this.hideAll()
    this.formTarget.classList.remove("hidden")
    if (this.hasInputTarget) {
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  cancel() {
    this.hideAll()
    if (this.hasTextTarget && this.textTarget.textContent.trim()) {
      this.displayTarget.classList.remove("hidden")
    } else {
      this.emptyTarget.classList.remove("hidden")
    }
  }

  handleSubmit(event) {
    if (event.detail.success) {
      const response = event.detail.fetchResponse.response
      if (response.ok) {
        this.hideAll()
        if (this.hasInputTarget && this.inputTarget.value.trim()) {
          this.textTarget.textContent = this.inputTarget.value
          this.displayTarget.classList.remove("hidden")
        } else {
          this.emptyTarget.classList.remove("hidden")
        }
      }
    }
  }

  hideAll() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.add("hidden")
    this.emptyTarget.classList.add("hidden")
  }
}
