import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "routeCard" ]

  connect() {
    this.draggedServiceEvent = null
    this.csrfToken = document.querySelector("meta[name='csrf-token']")?.content
  }

  dragStart(event) {
    const row = event.target.closest("[data-service-event-id]")
    if (!row) return

    this.draggedServiceEvent = row
    row.classList.add("opacity-60")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", row.dataset.serviceEventId || "")
    }
  }

  dragOver(event) {
    if (!this.draggedServiceEvent) return

    const routeCard = event.target.closest("[data-route-id]")
    if (!routeCard) return

    event.preventDefault()
    routeCard.classList.add("ring-2", "ring-emerald-500")
  }

  dragLeave(event) {
    const routeCard = event.target.closest("[data-route-id]")
    if (!routeCard) return

    routeCard.classList.remove("ring-2", "ring-emerald-500")
  }

  async drop(event) {
    event.preventDefault()

    const routeCard = event.target.closest("[data-route-id]")
    if (!routeCard || !this.draggedServiceEvent) {
      this.clearDragState()
      return
    }

    routeCard.classList.remove("ring-2", "ring-emerald-500")

    const routeId = routeCard.dataset.routeId
    const serviceEventId = this.draggedServiceEvent.dataset.serviceEventId
    if (!routeId || !serviceEventId || !this.csrfToken) {
      this.clearDragState()
      return
    }

    try {
      const response = await fetch(`/routes/${routeId}/service_events/${serviceEventId}/assign`, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (response.ok) {
        window.location.reload()
        return
      }

      const payload = await response.json().catch(() => ({}))
      if (payload.message) {
        window.alert(payload.message)
      }
      window.location.reload()
    } catch (_error) {
      window.location.reload()
    } finally {
      this.clearDragState()
    }
  }

  dragEnd() {
    this.clearDragState()
  }

  clearDragState() {
    if (this.draggedServiceEvent) {
      this.draggedServiceEvent.classList.remove("opacity-60")
    }

    this.routeCardTargets.forEach((routeCard) => {
      routeCard.classList.remove("ring-2", "ring-emerald-500")
    })

    this.draggedServiceEvent = null
  }
}
