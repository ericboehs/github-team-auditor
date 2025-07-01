import { Application } from "@hotwired/stimulus"
import LocalTimeController from "../../../app/javascript/controllers/local_time_controller"

// Setup Stimulus application for testing
const application = Application.start()
application.register("local-time", LocalTimeController)

describe("LocalTimeController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="local-time"
          data-local-time-datetime-value="2023-06-15T14:30:00Z"
          data-local-time-format-value="short">
        <span data-local-time-target="time">Original text</span>
      </div>
    `
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  test("formats time in user's local timezone", async () => {
    // Wait for Stimulus to connect
    await new Promise(resolve => setTimeout(resolve, 10))

    const timeElement = document.querySelector('[data-local-time-target="time"]')

    // Should have updated the text from "Original text"
    expect(timeElement.textContent).not.toBe("Original text")
    expect(timeElement.textContent).toMatch(/Jun 15/)
  })

  test("handles missing datetime value gracefully", async () => {
    document.body.innerHTML = `
      <div data-controller="local-time" data-local-time-format-value="short">
        <span data-local-time-target="time">Original text</span>
      </div>
    `

    await new Promise(resolve => setTimeout(resolve, 10))

    const timeElement = document.querySelector('[data-local-time-target="time"]')

    // Should leave original text unchanged when no datetime provided
    expect(timeElement.textContent).toBe("Original text")
  })
})
