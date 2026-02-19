import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row", "number", "saveButton", "status" ]

  connect() {
    this.draggedRow = null
    this.startingOrder = null
    this.dirty = false
    this.updateSaveState()
  }

  dragStart(event) {
    const row = event.target.closest("[data-route-ordering-target='row']")
    if (!row) return

    this.startingOrder = this.currentOrder()
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
    this.markDirty()
    this.clearDragState()
  }

  dragEnd() {
    if (this.orderChanged()) {
      this.refreshNumbers()
      this.markDirty()
    }
    this.clearDragState()
  }

  refreshNumbers() {
    this.currentRows().forEach((row, idx) => {
      const numberEl = row.querySelector("[data-route-ordering-target='number']")
      if (numberEl) {
        numberEl.textContent = idx + 1
      }
    })
  }

  currentOrder() {
    return this.currentRows().map((row) => row.dataset.eventId).filter(Boolean)
  }

  currentRows() {
    return Array.from(this.element.querySelectorAll("[data-route-ordering-target='row']"))
  }

  orderChanged() {
    if (!this.startingOrder) return false
    const current = this.currentOrder()
    if (current.length !== this.startingOrder.length) return true
    return current.some((id, idx) => id !== this.startingOrder[idx])
  }

  save(event) {
    if (event) event.preventDefault()
    if (!this.dirty) return
    this.submitOrder()
  }

  clearDragState() {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("opacity-50")
    }
    this.draggedRow = null
    this.startingOrder = null
  }

  submitOrder() {
    const url = this.element.action
    if (!url) return

    const formData = new FormData()
    this.currentOrder().forEach((id) => {
      formData.append("event_ids[]", id)
    })

    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(url, {
      method: "PATCH",
      credentials: "same-origin",
      headers: token ? { "X-CSRF-Token": token } : {},
      body: formData
    }).then((response) => {
      if (response.redirected) {
        window.location = response.url
        return
      }
      if (response.ok) {
        this.markSaved()
        return
      }
      this.markFailed(response.status)
    }).catch((error) => {
      this.markFailed(error)
    })
  }

  markDirty() {
    this.dirty = true
    this.updateSaveState()
  }

  markSaved() {
    this.dirty = false
    this.updateSaveState({ message: "Saved" })
  }

  markFailed(error) {
    console.warn("Route ordering save failed", error)
    this.updateSaveState({ message: "Save failed" })
  }

  updateSaveState({ message } = {}) {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = !this.dirty
    }
    if (this.hasStatusTarget) {
      if (message) {
        this.statusTarget.textContent = message
      } else {
        this.statusTarget.textContent = this.dirty ? "Unsaved changes" : ""
      }
    }
  }
}
