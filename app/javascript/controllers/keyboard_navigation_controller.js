import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell"]
  
  connect() {
    this.currentCellIndex = 0
    this.highlightCurrentCell()
    
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
    
    switch (key) {
      // Vim-style navigation
      case 'h': // Left
        return this.moveLeft()
      case 'j': // Down
        return this.moveDown()
      case 'k': // Up
        return this.moveUp()
      case 'l': // Right
        return this.moveRight()
        
      // Emacs-style navigation
      case 'b': // Backward (Left)
        return this.moveLeft()
      case 'n': // Next line (Down)
        return this.moveDown()
      case 'p': // Previous line (Up)
        return this.moveUp()
      case 'f': // Forward (Right)
        return this.moveRight()
        
      default:
        return false
    }
  }
  
  moveLeft() {
    const currentRow = this.getCurrentRow()
    const currentCol = this.getCurrentCol()
    
    if (currentCol > 0) {
      this.moveTo(currentRow, currentCol - 1)
      return true
    }
    return false
  }
  
  moveRight() {
    const currentRow = this.getCurrentRow()
    const currentCol = this.getCurrentCol()
    const rowCellCount = this.getRowCellCount(currentRow)
    
    if (currentCol < rowCellCount - 1) {
      this.moveTo(currentRow, currentCol + 1)
      return true
    }
    return false
  }
  
  moveUp() {
    const currentRow = this.getCurrentRow()
    const currentCol = this.getCurrentCol()
    
    if (currentRow > 0) {
      this.moveTo(currentRow - 1, currentCol)
      return true
    }
    return false
  }
  
  moveDown() {
    const currentRow = this.getCurrentRow()
    const currentCol = this.getCurrentCol()
    const totalRows = this.getTotalRows()
    
    if (currentRow < totalRows - 1) {
      this.moveTo(currentRow + 1, currentCol)
      return true
    }
    return false
  }
  
  moveTo(row, col) {
    this.clearHighlight()
    
    const targetIndex = this.getCellIndex(row, col)
    if (targetIndex >= 0 && targetIndex < this.cellTargets.length) {
      this.currentCellIndex = targetIndex
      this.highlightCurrentCell()
      this.scrollToCurrentCell()
    }
  }
  
  getCurrentRow() {
    const cell = this.cellTargets[this.currentCellIndex]
    const row = cell.closest('tr')
    const tbody = row.closest('tbody')
    const rows = Array.from(tbody.querySelectorAll('tr'))
    return rows.indexOf(row)
  }
  
  getCurrentCol() {
    const cell = this.cellTargets[this.currentCellIndex]
    const row = cell.closest('tr')
    const cells = Array.from(row.querySelectorAll('td, th'))
    return cells.indexOf(cell)
  }
  
  getRowCellCount(rowIndex) {
    const tbody = this.element.querySelector('tbody')
    const rows = Array.from(tbody.querySelectorAll('tr'))
    if (rows[rowIndex]) {
      return rows[rowIndex].querySelectorAll('td, th').length
    }
    return 0
  }
  
  getTotalRows() {
    const tbody = this.element.querySelector('tbody')
    return tbody.querySelectorAll('tr').length
  }
  
  getCellIndex(row, col) {
    const tbody = this.element.querySelector('tbody')
    const rows = Array.from(tbody.querySelectorAll('tr'))
    
    if (rows[row]) {
      const cells = Array.from(rows[row].querySelectorAll('td, th'))
      if (cells[col]) {
        return this.cellTargets.indexOf(cells[col])
      }
    }
    return -1
  }
  
  highlightCurrentCell() {
    const currentCell = this.cellTargets[this.currentCellIndex]
    if (currentCell) {
      currentCell.classList.add('bg-blue-100', 'dark:bg-blue-900', 'ring-2', 'ring-blue-500', 'ring-inset')
      currentCell.setAttribute('data-keyboard-focus', 'true')
    }
  }
  
  clearHighlight() {
    this.cellTargets.forEach(cell => {
      cell.classList.remove('bg-blue-100', 'dark:bg-blue-900', 'ring-2', 'ring-blue-500', 'ring-inset')
      cell.removeAttribute('data-keyboard-focus')
    })
  }
  
  scrollToCurrentCell() {
    const currentCell = this.cellTargets[this.currentCellIndex]
    if (currentCell) {
      currentCell.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'center', 
        inline: 'nearest' 
      })
    }
  }
}