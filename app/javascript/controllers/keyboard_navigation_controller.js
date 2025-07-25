import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actionable"]

  // Get only visible and focusable actionable elements
  get visibleActionableTargets() {
    return this.actionableTargets.filter(element => {
      return this.isElementVisible(element) && this.isElementFocusable(element)
    })
  }

  connect() {
    this.currentItemIndex = null
    this.inIssueColumn = false
    this.currentIssueIndex = 0

    // Add global keydown listener
    document.addEventListener("keydown", this.handleKeydown.bind(this))

    // Auto-initialize navigation on page load for immediate keyboard nav
    this.autoInitializeNavigation()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    // Handle Enter key for expanding issue lists
    if (event.key === 'Enter' && !event.ctrlKey && !event.shiftKey && !event.altKey) {
      const activeElement = document.activeElement
      if (activeElement && this.isExpandToggleButton(activeElement)) {
        // Let the default action happen first, then handle navigation after expansion
        setTimeout(() => this.handleIssueExpansion(activeElement), 0)
        return
      }
    }

    // Handle Ctrl+/ (or Ctrl+?) for help modal
    if (event.ctrlKey && (event.key === '/' || event.key === '?')) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleHelpModal()
      return
    }

    // Only handle other navigation when Ctrl is pressed
    if (!event.ctrlKey) return

    // Prevent default browser behavior for our shortcuts
    const handled = this.processNavigationKey(event)
    if (handled) {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  processNavigationKey(event) {
    const key = event.key.toLowerCase()

    // Handle help modal toggle (Ctrl+/)
    if (key === '/') {
      return this.toggleHelpModal()
    }

    // Check if this is a valid navigation key before initializing
    const isValidNavigationKey = ['h', 'l', 'k', 'j', 'b', 'f', 'p', 'n'].includes(key)
    if (!isValidNavigationKey) {
      return false
    }

    // Initialize if this is the first navigation
    if (this.currentItemIndex === null) {
      this.initializeNavigation()
    }

    switch (key) {
      // Vim-style navigation
      case 'h': // Previous item in row
        return this.movePrevious()
      case 'l': // Next item in row
        return this.moveNext()
      case 'k': // Previous item in same column
        return this.moveUp()
      case 'j': // Next item in same column
        return this.moveDown()

      // Emacs-style navigation
      case 'b': // Previous item in row
        return this.movePrevious()
      case 'f': // Next item in row
        return this.moveNext()
      case 'p': // Previous item in same column
        return this.moveUp()
      case 'n': // Next item in same column
        return this.moveDown()

      default:
        return false
    }
  }

  initializeNavigation() {
    // Check if the currently focused element is one of our actionable targets
    const currentlyFocused = document.activeElement
    const visibleTargets = this.visibleActionableTargets
    const focusedIndex = visibleTargets.indexOf(currentlyFocused)

    if (focusedIndex !== -1) {
      // Sync with the currently focused element from tab navigation
      this.currentItemIndex = focusedIndex
      this.currentIssueIndex = 0

      // Don't change focus since it's already where it should be
      // Just update our internal tracking and issue index if needed
      if (this.isInIssuesColumn(currentlyFocused)) {
        const issueLinks = this.getIssueLinksInSameCell(currentlyFocused)
        const issueIndex = issueLinks.indexOf(currentlyFocused)
        if (issueIndex !== -1) {
          this.currentIssueIndex = issueIndex
        }
      }
    } else {
      // No actionable element is focused, start at the first one
      this.currentItemIndex = 0
      this.currentIssueIndex = 0
      this.focusCurrentItem()
    }
  }

  movePrevious() {
    if (this.currentItemIndex > 0) {
      this.currentItemIndex--
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveNext() {
    const visibleTargets = this.visibleActionableTargets
    const currentItem = visibleTargets[this.currentItemIndex]

    // Check if we're in an issues column and should navigate within it
    if (this.isInIssuesColumn(currentItem)) {
      const issueLinks = this.getIssueLinksInSameCell(currentItem)
      if (issueLinks.length > 1 && this.currentIssueIndex < issueLinks.length - 1) {
        this.currentIssueIndex++
        this.focusIssueLink(issueLinks[this.currentIssueIndex])
        return true
      }
    }

    // Regular navigation to next column
    if (this.currentItemIndex < visibleTargets.length - 1) {
      this.currentItemIndex++
      this.currentIssueIndex = 0 // Reset issue index when moving to different cell
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveUp() {
    const visibleTargets = this.visibleActionableTargets
    const currentItem = visibleTargets[this.currentItemIndex]

    // Check if we're in an issues column and should navigate within it
    if (this.isInIssuesColumn(currentItem)) {
      const issueLinks = this.getIssueLinksInSameCell(currentItem)
      if (issueLinks.length > 1 && this.currentIssueIndex > 0) {
        this.currentIssueIndex--
        this.focusIssueLink(issueLinks[this.currentIssueIndex])
        return true
      }
    }

    // Regular navigation to previous row
    const currentColumn = this.getColumnIndex(currentItem)
    const currentRow = this.getRowIndex(currentItem)

    // Find the same column in the previous row
    const targetItem = this.findItemInColumn(currentColumn, currentRow - 1)
    if (targetItem && this.isElementVisible(targetItem) && this.isElementFocusable(targetItem)) {
      const targetIndex = visibleTargets.indexOf(targetItem)
      if (targetIndex !== -1) {
        this.currentItemIndex = targetIndex
        this.currentIssueIndex = 0 // Reset issue index when moving to different row
        this.focusCurrentItem()
        return true
      }
    }
    return false
  }

  moveDown() {
    const visibleTargets = this.visibleActionableTargets
    const currentItem = visibleTargets[this.currentItemIndex]

    // Check if we're in an issues column and should navigate within it
    if (this.isInIssuesColumn(currentItem)) {
      const issueLinks = this.getIssueLinksInSameCell(currentItem)
      if (issueLinks.length > 1 && this.currentIssueIndex < issueLinks.length - 1) {
        this.currentIssueIndex++
        this.focusIssueLink(issueLinks[this.currentIssueIndex])
        return true
      }
    }

    // Regular navigation to next row
    const currentColumn = this.getColumnIndex(currentItem)
    const currentRow = this.getRowIndex(currentItem)

    // Find the same column in the next row
    const targetItem = this.findItemInColumn(currentColumn, currentRow + 1)
    if (targetItem && this.isElementVisible(targetItem) && this.isElementFocusable(targetItem)) {
      const targetIndex = visibleTargets.indexOf(targetItem)
      if (targetIndex !== -1) {
        this.currentItemIndex = targetIndex
        this.currentIssueIndex = 0 // Reset issue index when moving to different row
        this.focusCurrentItem()
        return true
      }
    }
    return false
  }

  focusCurrentItem() {
    // Clear any text selection when changing focus
    this.clearTextSelection()

    const visibleTargets = this.visibleActionableTargets
    const currentItem = visibleTargets[this.currentItemIndex]
    if (currentItem) {
      // If we're in an issues column, focus on the appropriate issue link
      if (this.isInIssuesColumn(currentItem)) {
        const issueLinks = this.getIssueLinksInSameCell(currentItem)
        if (issueLinks.length > 0) {
          this.focusIssueLink(issueLinks[this.currentIssueIndex])
          return
        }
      }

      currentItem.focus()

      // Show tooltip if this is an access expires column
      this.showTooltipIfAccessExpires(currentItem)
    }
  }

  focusIssueLink(issueLink) {
    if (issueLink) {
      issueLink.focus()
    }
  }

  clearTextSelection() {
    // Clear any text selection in the document
    if (window.getSelection) {
      const selection = window.getSelection()
      if (selection.rangeCount > 0) {
        selection.removeAllRanges()
      }
    }
  }

  showTooltipIfAccessExpires(item) {
    // Check if this item is in the access expires column (column index 4)
    const columnIndex = this.getColumnIndex(item)
    if (columnIndex === 4) { // Access expires column
      // The tooltip will be shown automatically via focus event handler in the HTML
      // No additional JavaScript needed since we added focus->tooltip#show to the element
    }
  }

  isInIssuesColumn(item) {
    // Check if this item is in the issues column (column index 3)
    const columnIndex = this.getColumnIndex(item)
    return columnIndex === 3
  }

  getIssueLinksInSameCell(item) {
    const cell = item.closest('td')
    if (!cell) return []

    // Get all issue links and toggle buttons in this cell
    const issueLinks = Array.from(cell.querySelectorAll('[data-keyboard-navigation-target="issue_link"]'))
    const actionableInCell = cell.querySelector('[data-keyboard-navigation-target="actionable"]')

    // Combine actionable item with issue links
    const allLinks = []
    if (actionableInCell) allLinks.push(actionableInCell)
    allLinks.push(...issueLinks)

    // Filter to only include visible and focusable elements
    return allLinks.filter(link => this.isElementVisible(link) && this.isElementFocusable(link))
  }

  getColumnIndex(item) {
    // Find which table cell contains this item, then determine its column index
    const cell = item.closest('td, th')
    if (!cell) return -1

    const row = cell.closest('tr')
    if (!row) return -1

    const cells = Array.from(row.querySelectorAll('td, th'))
    return cells.indexOf(cell)
  }

  getRowIndex(item) {
    // Find which table row contains this item, then determine its row index
    const row = item.closest('tr')
    if (!row) return -1

    const tbody = row.closest('tbody')
    if (!tbody) return -1

    const rows = Array.from(tbody.querySelectorAll('tr'))
    return rows.indexOf(row)
  }

  findItemInColumn(columnIndex, rowIndex) {
    // Find the table body and get the specific row
    const tbody = this.element.querySelector('tbody')
    if (!tbody) return null

    const rows = Array.from(tbody.querySelectorAll('tr'))
    if (rowIndex < 0 || rowIndex >= rows.length) return null

    const targetRow = rows[rowIndex]
    const cells = Array.from(targetRow.querySelectorAll('td, th'))
    if (columnIndex < 0 || columnIndex >= cells.length) return null

    const targetCell = cells[columnIndex]

    // Find the first actionable item in this cell
    const actionableInCell = targetCell.querySelector('[data-keyboard-navigation-target="actionable"]')

    // Only return if this item is in our actionable targets list and is visible/focusable
    if (actionableInCell && this.actionableTargets.includes(actionableInCell)) {
      return actionableInCell
    }

    return null
  }

  autoInitializeNavigation() {
    // Don't auto-initialize the index anymore - let the first Ctrl+J/L do the initialization
    // This ensures the first keyboard navigation visually focuses the first element
  }

  isExpandToggleButton(element) {
    // Check if this is a "+more" expand button in the issues column
    return element.hasAttribute('data-issue-list-target') &&
          element.getAttribute('data-issue-list-target') === 'toggleButton' &&
          element.textContent.includes('more')
  }

  handleIssueExpansion(toggleButton) {
    // Find the cell containing this toggle button
    const cell = toggleButton.closest('td')
    if (!cell) return

    // Find the expanded section that should now be visible
    const expandedSection = cell.querySelector('[data-issue-list-target="expanded"]')
    if (!expandedSection || expandedSection.hidden) return

    // Find the first issue link in the expanded section that wasn't in the summary
    // The summary shows first 2 issues, so we want to focus on the 3rd issue (index 2)
    const allIssueLinks = Array.from(expandedSection.querySelectorAll('[data-keyboard-navigation-target="issue_link"]'))

    // Focus on the first issue that wasn't visible in the summary (3rd issue, index 2)
    if (allIssueLinks.length > 2) {
      const targetIssue = allIssueLinks[2] // 3rd issue (0-indexed)
      targetIssue.focus()

      // Update our navigation state to track this new position
      this.updateNavigationStateAfterExpansion(targetIssue)
    }
  }

  updateNavigationStateAfterExpansion(focusedElement) {
    // Find this element in our actionable targets and update indices
    const cell = focusedElement.closest('td')
    const actionableInCell = cell.querySelector('[data-keyboard-navigation-target="actionable"]')

    if (actionableInCell) {
      const actionableIndex = this.actionableTargets.indexOf(actionableInCell)
      if (actionableIndex !== -1) {
        this.currentItemIndex = actionableIndex

        // Find which issue index this corresponds to within the cell
        const allIssueLinksInCell = this.getIssueLinksInSameCell(actionableInCell)
        const issueIndex = allIssueLinksInCell.indexOf(focusedElement)
        if (issueIndex !== -1) {
          this.currentIssueIndex = issueIndex
        }
      }
    }
  }

  toggleHelpModal() {
    // Find the help modal controller
    const helpModalElement = document.querySelector('[data-controller*="help-modal"]')
    if (helpModalElement) {
      const helpModalController = this.application.getControllerForElementAndIdentifier(
        helpModalElement,
        'help-modal'
      )
      if (helpModalController) {
        helpModalController.toggle()
        return true
      }
    }
    return false
  }

  isElementVisible(element) {
    // Check if element is visible using multiple criteria
    if (!element) return false

    // Check if element or any parent is hidden
    let current = element
    while (current && current !== document.body) {
      if (current.hidden ||
          current.style.display === 'none' ||
          current.style.visibility === 'hidden' ||
          current.classList.contains('hidden')) {
        return false
      }
      current = current.parentElement
    }

    // Check computed styles
    const style = window.getComputedStyle(element)
    if (style.display === 'none' ||
        style.visibility === 'hidden' ||
        style.opacity === '0') {
      return false
    }

    // Check if element has actual dimensions
    const rect = element.getBoundingClientRect()
    return rect.width > 0 && rect.height > 0
  }

  isElementFocusable(element) {
    // Check if element is focusable
    if (!element) return false

    // Check tabindex
    const tabIndex = element.getAttribute('tabindex')
    if (tabIndex === '-1') return false

    // Check if element is disabled
    if (element.disabled) return false

    // Check if element is naturally focusable or has tabindex >= 0
    const focusableElements = ['input', 'button', 'select', 'textarea', 'a']
    const tagName = element.tagName.toLowerCase()

    return focusableElements.includes(tagName) ||
          (tabIndex !== null && parseInt(tabIndex) >= 0)
  }
}
