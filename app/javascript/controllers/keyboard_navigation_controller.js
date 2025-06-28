import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actionable"]

  connect() {
    this.currentItemIndex = null

    // Add global keydown listener
    document.addEventListener("keydown", this.handleKeydown.bind(this))
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
    if (this.currentItemIndex < this.actionableTargets.length - 1) {
      this.currentItemIndex++
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveUp() {
    const currentItem = this.actionableTargets[this.currentItemIndex]
    const currentColumn = this.getColumnIndex(currentItem)
    const currentRow = this.getRowIndex(currentItem)

    // Find the same column in the previous row
    const targetItem = this.findItemInColumn(currentColumn, currentRow - 1)
    if (targetItem) {
      const targetIndex = this.actionableTargets.indexOf(targetItem)
      this.currentItemIndex = targetIndex
      this.focusCurrentItem()
      return true
    }
    return false
  }

  moveDown() {
    const currentItem = this.actionableTargets[this.currentItemIndex]
    const currentColumn = this.getColumnIndex(currentItem)
    const currentRow = this.getRowIndex(currentItem)

    // Find the same column in the next row
    const targetItem = this.findItemInColumn(currentColumn, currentRow + 1)
    if (targetItem) {
      const targetIndex = this.actionableTargets.indexOf(targetItem)
      this.currentItemIndex = targetIndex
      this.focusCurrentItem()
      return true
    }
    return false
  }

  focusCurrentItem() {
    const currentItem = this.actionableTargets[this.currentItemIndex]
    if (currentItem) {
      currentItem.focus()
    }
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
}
