import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="local-time"
export default class extends Controller {
  static targets = ["time"]
  static values = {
    datetime: String,
    format: String
  }

  connect() {
    this.formatTime()
  }

  formatTime() {
    if (!this.datetimeValue) return

    const date = new Date(this.datetimeValue)
    const currentYear = new Date().getFullYear()

    let formatted
    if (this.formatValue === "short" && date.getFullYear() === currentYear) {
      // For current year: "Jan 15 at 2:30 PM"
      formatted = date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric"
      }) + " at " + date.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        hour12: true
      })
    } else if (this.formatValue === "short") {
      // For other years: "Jan 15, 2023 at 2:30 PM" (still show time for tooltip context)
      formatted = date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric"
      }) + " at " + date.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        hour12: true
      })
    } else {
      // Default format with full date and time
      formatted = date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric"
      }) + " at " + date.toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        hour12: true
      })
    }

    this.timeTarget.textContent = formatted
  }
}
