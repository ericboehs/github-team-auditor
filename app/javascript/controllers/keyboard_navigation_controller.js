import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actionable"]

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
    // Only handle navigation when Ctrl is pressed
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
    // Start at the first actionable item
    this.currentItemIndex = 0
    this.focusCurrentItem()
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
    const currentItem = this.actionableTargets[this.currentItemIndex]

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
    if (this.currentItemIndex < this.actionableTargets.length - 1) {
      this.currentItemIndex++
      this.currentIssueIndex = 0 // Reset issue index when moving to different cell
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveUp() {
    const currentItem = this.actionableTargets[this.currentItemIndex]

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
    if (targetItem) {
      const targetIndex = this.actionableTargets.indexOf(targetItem)
      this.currentItemIndex = targetIndex
      this.currentIssueIndex = 0 // Reset issue index when moving to different row
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveDown() {
    const currentItem = this.actionableTargets[this.currentItemIndex]

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
    if (targetItem) {
      const targetIndex = this.actionableTargets.indexOf(targetItem)
      this.currentItemIndex = targetIndex
      this.currentIssueIndex = 0 // Reset issue index when moving to different row
      this.focusCurrentItem()
      return true
    }
    return false
  }

  focusCurrentItem() {
    // Clear any text selection when changing focus
    this.clearTextSelection()

    const currentItem = this.actionableTargets[this.currentItemIndex]
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

    return allLinks
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

    // Only return if this item is in our actionable targets list
    if (actionableInCell && this.actionableTargets.includes(actionableInCell)) {
      return actionableInCell
    }

    return null
  }

  autoInitializeNavigation() {
    // Auto-focus the first actionable element to enable immediate keyboard navigation
    if (this.actionableTargets.length > 0) {
      this.currentItemIndex = 0
      // Don't actually focus visually, just set up the state for keyboard navigation
      // This way users won't see an unexpected focus ring on page load
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
}
