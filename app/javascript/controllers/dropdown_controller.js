import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu", "input"]

  connect() {
    this.close = this.close.bind(this)
    this.closeOnGlobalEvent = this.closeOnGlobalEvent.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)

    // Listen for global dropdown open events
    document.addEventListener("dropdown:open", this.closeOnGlobalEvent)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    // Dispatch event to close other dropdowns
    document.dispatchEvent(new CustomEvent("dropdown:open", {
      detail: { source: this.element }
    }))

    this.menuTarget.classList.remove("opacity-0", "scale-95", "pointer-events-none")
    this.menuTarget.classList.add("opacity-100", "scale-100")
    this.menuTarget.removeAttribute("inert")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    // Focus input field if it exists
    if (this.hasInputTarget) {
      setTimeout(() => this.inputTarget.focus(), 100)
    }

    // Add event listeners
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleKeydown)
  }

  closeOnGlobalEvent(event) {
    // Close this dropdown if another one is opening
    if (event.detail.source !== this.element && this.isOpen()) {
      this.closeMenu()
    }
  }

  closeMenu() {
    this.menuTarget.classList.remove("opacity-100", "scale-100")
    this.menuTarget.classList.add("opacity-0", "scale-95", "pointer-events-none")
    this.menuTarget.setAttribute("inert", "")
    this.buttonTarget.setAttribute("aria-expanded", "false")

    // Restore focus to button
    this.buttonTarget.focus()

    // Remove event listeners
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  close(event) {
    // Don't close if date field is currently active
    if (this.dateFieldActive) {
      return
    }

    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  isOpen() {
    return this.menuTarget.classList.contains("opacity-100")
  }

  handleKeydown(event) {
    if (!this.isOpen()) return

    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.closeMenu()
        break
      case "ArrowDown":
        event.preventDefault()
        this.focusNextMenuItem()
        break
      case "ArrowUp":
        event.preventDefault()
        this.focusPreviousMenuItem()
        break
      case "Home":
        event.preventDefault()
        this.focusFirstMenuItem()
        break
      case "End":
        event.preventDefault()
        this.focusLastMenuItem()
        break
    }
  }

  focusFirstMenuItem() {
    const menuItems = this.getMenuItems()
    if (menuItems.length > 0) {
      menuItems[0].focus()
    }
  }

  focusLastMenuItem() {
    const menuItems = this.getMenuItems()
    if (menuItems.length > 0) {
      menuItems[menuItems.length - 1].focus()
    }
  }

  focusNextMenuItem() {
    const menuItems = this.getMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex === -1) {
      // No item focused, focus first item
      if (menuItems.length > 0) {
        menuItems[0].focus()
      }
    } else if (currentIndex < menuItems.length - 1) {
      // Focus next item
      menuItems[currentIndex + 1].focus()
    }
  }

  focusPreviousMenuItem() {
    const menuItems = this.getMenuItems()
    const currentIndex = this.getCurrentMenuItemIndex(menuItems)

    if (currentIndex === -1) {
      // No item focused, focus last item
      if (menuItems.length > 0) {
        menuItems[menuItems.length - 1].focus()
      }
    } else if (currentIndex > 0) {
      // Focus previous item
      menuItems[currentIndex - 1].focus()
    }
  }

  getMenuItems() {
    // Get all focusable menu items, excluding dividers
    return Array.from(this.menuTarget.querySelectorAll('[role="menuitem"]:not([disabled])'))
  }

  getCurrentMenuItemIndex(menuItems) {
    return menuItems.findIndex(item => item === document.activeElement)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("dropdown:open", this.closeOnGlobalEvent)
  }
}
