import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu", "input"]

  connect() {
    this.close = this.close.bind(this)
    this.closeOnGlobalEvent = this.closeOnGlobalEvent.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleFocusOut = this.handleFocusOut.bind(this)

    // Listen for global dropdown open events
    document.addEventListener("dropdown:open", this.closeOnGlobalEvent)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Store which button was clicked for focus restoration
    this.activeButton = event.currentTarget

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

    // Focus input field if it exists, otherwise don't auto-focus any menu item
    setTimeout(() => {
      if (this.hasInputTarget) {
        this.inputTarget.focus()
      }
      // Don't auto-focus first menu item - let user navigate with Tab/Arrow keys
    }, 100) // Small delay to ensure the dropdown is fully open

    // Add click outside, escape key, and focus out listeners
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("focusout", this.handleFocusOut)
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

    // Restore focus to the specific button that was clicked
    if (this.activeButton) {
      this.activeButton.focus()
    } else {
      // Fallback to the first visible button
      this.buttonTarget.focus()
    }

    // Remove event listeners
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("focusout", this.handleFocusOut)
  }

  close(event) {
    // Don't close if date field is currently active (mobile date picker interaction)
    if (this.dateFieldActive) {
      return
    }

    // Don't close if the target is a date input (iOS date picker might not be contained)
    if (event.target && event.target.type === 'date') {
      return
    }

    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  handleFocusOut(event) {
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)

    // Use setTimeout to allow focus to move to the new element first
    setTimeout(() => {
      // Don't close if date field is currently active (mobile date picker interaction)
      if (this.dateFieldActive) {
        return
      }

      // On iOS, be more lenient with focus changes from date inputs
      const isIOSDateInput = isIOS &&
                          event.target &&
                          event.target.type === 'date'

      if (isIOSDateInput) {
        // Give iOS more time for date picker interactions
        return
      }

      // Check if focus has moved outside the dropdown
      if (this.isOpen() && !this.element.contains(document.activeElement)) {
        this.closeMenu()
      }
    }, 0)
  }

  // Direct close action for menu items
  closeAction(event) {
    this.closeMenu()
  }

  // Clear flash messages when starting new operations
  clearFlashMessages(event) {
    console.log('clearFlashMessages called')

    // Clear flash messages only
    const flashMessagesContainer = document.getElementById('flash-messages')
    if (flashMessagesContainer) {
      console.log('Clearing flash messages')
      flashMessagesContainer.innerHTML = ''
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
    document.removeEventListener("focusout", this.handleFocusOut)
    document.removeEventListener("dropdown:open", this.closeOnGlobalEvent)
  }
}
