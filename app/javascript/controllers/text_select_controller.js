import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  focus() {
    // Select all text when the element receives focus
    const selection = window.getSelection()
    const range = document.createRange()
    range.selectNodeContents(this.element)
    selection.removeAllRanges()
    selection.addRange(range)
  }
}
