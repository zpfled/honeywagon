import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row", "number", "inputContainer" ]

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest("[data-route-ordering-target='row']")
    if (!row) return

    const rows = this.rowTargets
    const index = rows.indexOf(row)
    if (index > 0) {
      row.parentNode.insertBefore(row, rows[index - 1])
      this.refreshNumbers()
    }
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest("[data-route-ordering-target='row']")
    if (!row) return

    const rows = this.rowTargets
    const index = rows.indexOf(row)
    if (index >= 0 && index < rows.length - 1) {
      row.parentNode.insertBefore(rows[index + 1], row)
      this.refreshNumbers()
    }
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
}
