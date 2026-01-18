import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row", "number", "inputContainer" ]

  connect() {
    this.draggedRow = null
  }

  dragStart(event) {
    const row = event.target.closest("[data-route-ordering-target='row']")
    if (!row) return

    this.draggedRow = row
    row.classList.add("opacity-50")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", row.dataset.eventId || "")
    }
  }

  dragOver(event) {
    if (!this.draggedRow) return

    const row = event.target.closest("[data-route-ordering-target='row']")
    event.preventDefault()
    if (!row || row === this.draggedRow) return

    const rect = row.getBoundingClientRect()
    const shouldInsertAfter = event.clientY > rect.top + rect.height / 2

    if (shouldInsertAfter) {
      row.parentNode.insertBefore(this.draggedRow, row.nextSibling)
    } else {
      row.parentNode.insertBefore(this.draggedRow, row)
    }

    this.refreshNumbers()
  }

  drop(event) {
    if (!this.draggedRow) return

    event.preventDefault()
    const row = event.target.closest("[data-route-ordering-target='row']")
    if (row && row !== this.draggedRow) {
      const rect = row.getBoundingClientRect()
      const shouldInsertAfter = event.clientY > rect.top + rect.height / 2

      if (shouldInsertAfter) {
        row.parentNode.insertBefore(this.draggedRow, row.nextSibling)
      } else {
        row.parentNode.insertBefore(this.draggedRow, row)
      }
    }

    this.refreshNumbers()
    this.buildInputs()
    this.element.requestSubmit()
    this.clearDragState()
  }

  dragEnd() {
    this.clearDragState()
  }

  submit(event) {
    this.buildInputs()
  }

  refreshNumbers() {
    this.rowTargets.forEach((row, idx) => {
      const numberEl = row.querySelector("[data-route-ordering-target='number']")
      if (numberEl) {
        numberEl.textContent = idx + 1
      }
    })
  }

  buildInputs() {
    if (!this.hasInputContainerTarget) return

    const container = this.inputContainerTarget
    container.innerHTML = ""

    this.rowTargets.forEach((row) => {
      const id = row.dataset.eventId
      if (!id) return

      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "event_ids[]"
      input.value = id
      container.appendChild(input)
    })
  }

  clearDragState() {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("opacity-50")
    }
    this.draggedRow = null
  }
}
