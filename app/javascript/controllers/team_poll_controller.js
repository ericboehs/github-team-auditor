import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="team-poll"
export default class extends Controller {
  static values = {
    url: String,
    interval: Number
  }

  connect() {
    this.startPolling()

    // Pause polling when page is not visible to reduce server load
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.handleVisibilityChange)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener('visibilitychange', this.handleVisibilityChange)
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.pause()
    } else {
      this.resume()
      // Poll immediately when page becomes visible
      this.poll()
    }
  }

  startPolling() {
    // Clear any existing interval
    this.stopPolling()

    // Start polling at the specified interval (default 5 seconds)
    this.pollTimer = setInterval(() => {
      this.poll()
    }, this.intervalValue || 5000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        method: 'GET',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const turboStream = await response.text()
        Turbo.renderStreamMessage(turboStream)
      } else {
        console.warn('Polling request failed:', response.status)
      }
    } catch (error) {
      console.warn('Polling error:', error)
      // Don't stop polling on errors - network issues are common
    }
  }

  // Allow manual refresh trigger
  refresh() {
    this.poll()
  }

  // Pause/resume polling (useful for when tab is not visible)
  pause() {
    this.stopPolling()
  }

  resume() {
    this.startPolling()
  }
}
