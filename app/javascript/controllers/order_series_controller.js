import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "section", "rows", "template"]

  connect() {
    if (this.hasToggleTarget && this.toggleTarget.checked) {
      this.showSection()
    }
  }

  toggle() {
    if (this.toggleTarget.checked) {
      this.showSection()
      if (this.rowsTarget.children.length === 0) this.addRow()
    } else {
      this.hideSection()
    }
  }

  addRow() {
    if (!this.hasTemplateTarget || !this.hasRowsTarget) return
    const fragment = this.templateTarget.content.cloneNode(true)
    this.rowsTarget.appendChild(fragment)
  }

  removeRow(event) {
    const row = event.target.closest("div")
    if (!row) return
    row.remove()
  }

  showSection() {
    if (this.hasSectionTarget) this.sectionTarget.classList.remove("hidden")
  }

  hideSection() {
    if (this.hasSectionTarget) this.sectionTarget.classList.add("hidden")
  }
}
