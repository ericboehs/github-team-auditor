import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  updateUrl(event) {
    // Get the href from the clicked link
    const href = event.currentTarget.href

    // Update the browser URL without refreshing the page
    window.history.pushState({}, '', href)

    // Let Turbo handle the frame update
    return true
  }
}
