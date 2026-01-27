import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "day",
    "list",
    "count",
    "modal",
    "modalDateLabel",
    "modalWarning",
    "mergeSelect",
    "mergeOption",
    "optionNew",
    "optionMerge",
    "modalContinue",
    "modalCancel",
    "toast",
    "toastMessage",
    "toastUndo"
  ]

  connect() {
    this.draggedCard = null
    const token = document.querySelector("meta[name='csrf-token']")
    this.csrfToken = token ? token.content : null
  }

  dragStart(event) {
    const card = event.target.closest("[data-route-id]")
    if (!card) return

    this.draggedCard = card
    card.classList.add("opacity-60")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", card.dataset.routeId || "")
    }
  }

  dragOver(event) {
    if (!this.draggedCard) return

    const day = event.target.closest("[data-routes-calendar-target='day']")
    if (!day) return

    event.preventDefault()
    day.classList.add("ring-1", "ring-brand-primary")
  }

  dragLeave(event) {
    const day = event.target.closest("[data-routes-calendar-target='day']")
    if (!day) return

    day.classList.remove("ring-1", "ring-brand-primary")
  }

  drop(event) {
    if (!this.draggedCard) return

    event.preventDefault()
    const day = event.target.closest("[data-routes-calendar-target='day']")
    if (!day) return

    day.classList.remove("ring-1", "ring-brand-primary")

    const newDate = day.dataset.date
    const currentDate = this.draggedCard.dataset.routeDate
    if (!newDate || newDate === currentDate) {
      this.clearDragState()
      return
    }

    const dayCards = this.routeCardsForDay(day)
    const hasExistingRoutes = dayCards.filter((card) => card !== this.draggedCard).length > 0
    const needsModal = hasExistingRoutes || this.isPastDate(newDate)

    if (needsModal) {
      this.openMoveModal({ day, newDate, hasExistingRoutes, dayCards })
      return
    }

    this.moveCardToDay(day, newDate)
    this.persistRouteDate(this.draggedCard.dataset.routeId, newDate)
    this.clearDragState()
  }

  dragEnd() {
    if (this.pendingMove) return
    this.clearDragState()
  }

  async persistRouteDate(routeId, routeDate) {
    if (!routeId || !this.csrfToken) return

    try {
      const response = await fetch(`/routes/${routeId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ route: { route_date: routeDate } })
      })

      if (!response.ok) {
        window.location.reload()
      }
    } catch (_error) {
      window.location.reload()
    }
  }

  async persistRouteMerge(sourceId, targetId) {
    if (!sourceId || !targetId || !this.csrfToken) return

    try {
      const response = await fetch(`/routes/${sourceId}/merge`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ target_id: targetId })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        window.location.reload()
      }
    } catch (_error) {
      window.location.reload()
    }
  }

  updateCountForDay(day) {
    const date = day.dataset.date
    const countEl = this.countTargets.find((node) => node.dataset.date === date)
    if (!countEl) return

    const list = day.querySelector("[data-routes-calendar-target='list']")
    const cards = list ? list.querySelectorAll("[data-route-id]").length : 0
    countEl.textContent = `${cards} route${cards === 1 ? "" : "s"}`
  }

  moveCardToDay(day, newDate) {
    const previousDay = this.dayTargets.find((node) => node.dataset.date === this.draggedCard.dataset.routeDate)
    const list = day.querySelector("[data-routes-calendar-target='list']")
    if (!list) return

    list.appendChild(this.draggedCard)
    this.draggedCard.dataset.routeDate = newDate
    this.updateCountForDay(day)
    if (previousDay) this.updateCountForDay(previousDay)
  }

  routeCardsForDay(day) {
    const list = day.querySelector("[data-routes-calendar-target='list']")
    return list ? Array.from(list.querySelectorAll("[data-route-id]")) : []
  }

  openMoveModal({ day, newDate, hasExistingRoutes, dayCards }) {
    this.pendingMove = { day, newDate, dayCards, previousDate: this.draggedCard.dataset.routeDate }
    if (this.hasModalDateLabelTarget) {
      this.modalDateLabelTarget.textContent = `Move to ${newDate}`
    }
    if (this.hasModalWarningTarget) {
      this.modalWarningTarget.classList.toggle("hidden", !this.isPastDate(newDate))
    }

    if (this.hasMergeOptionTarget) {
      this.mergeOptionTarget.classList.toggle("hidden", !hasExistingRoutes)
    }

    if (this.hasOptionNewTarget) {
      this.optionNewTarget.checked = true
    }

    const options = hasExistingRoutes
      ? dayCards
          .filter((card) => card !== this.draggedCard)
          .map((card) => ({
            id: card.dataset.routeId,
            label: card.dataset.routeLabel || "Route"
          }))
      : []
    this.populateMergeSelect(options)

    if (options.length === 1 && this.hasOptionMergeTarget) {
      this.optionMergeTarget.checked = true
    }

    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.modalTarget.classList.add("flex")
    }
  }

  populateMergeSelect(options) {
    if (!this.hasMergeSelectTarget) return
    this.mergeSelectTarget.innerHTML = ""
    options.forEach((option) => {
      const el = document.createElement("option")
      el.value = option.id
      el.textContent = option.label
      this.mergeSelectTarget.appendChild(el)
    })
  }

  async confirmModal() {
    if (!this.pendingMove || !this.draggedCard) return
    const { day, newDate, dayCards } = this.pendingMove
    const wantsMerge = this.hasOptionMergeTarget && this.optionMergeTarget.checked

    if (wantsMerge) {
      const targetId = this.mergeSelectTarget ? this.mergeSelectTarget.value : null
      if (!targetId) return
      this.setModalSaving(true)
      await this.persistRouteMerge(this.draggedCard.dataset.routeId, targetId)
      this.setModalSaving(false)
      this.closeModal()
      this.clearDragState()
      return
    }

    this.setModalSaving(true)
    this.moveCardToDay(day, newDate)
    await this.persistRouteDate(this.draggedCard.dataset.routeId, newDate)
    this.setModalSaving(false)
    this.showToast({
      routeId: this.draggedCard.dataset.routeId,
      previousDate: this.pendingMove.previousDate,
      newDate
    })
    this.closeModal()
    this.clearDragState()
  }

  cancelModal() {
    this.closeModal()
    this.clearDragState()
  }

  maybeCloseModal(event) {
    if (event.key === "Escape") {
      this.cancelModal()
    }
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.modalTarget.classList.remove("flex")
    }
    this.pendingMove = null
  }

  setModalSaving(isSaving) {
    if (this.hasModalContinueTarget) {
      const label = this.modalContinueTarget.dataset.defaultLabel || "Continue"
      this.modalContinueTarget.textContent = isSaving ? "Saving…" : label
      this.modalContinueTarget.disabled = isSaving
      this.modalContinueTarget.classList.toggle("opacity-60", isSaving)
      this.modalContinueTarget.classList.toggle("cursor-not-allowed", isSaving)
    }
    if (this.hasModalCancelTarget) {
      this.modalCancelTarget.disabled = isSaving
      this.modalCancelTarget.classList.toggle("opacity-60", isSaving)
      this.modalCancelTarget.classList.toggle("cursor-not-allowed", isSaving)
    }
  }

  showToast({ routeId, previousDate, newDate }) {
    if (!this.hasToastTarget) return
    this.toastTarget.classList.remove("hidden")
    this.toastTarget.dataset.routeId = routeId
    this.toastTarget.dataset.previousDate = previousDate
    this.toastTarget.dataset.newDate = newDate
    if (this.hasToastMessageTarget) {
      this.toastMessageTarget.textContent = "Moved."
    }
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.hideToast(), 4000)
  }

  hideToast() {
    if (this.hasToastTarget) {
      this.toastTarget.classList.add("hidden")
    }
  }

  async undoMove() {
    if (!this.hasToastTarget) return
    const routeId = this.toastTarget.dataset.routeId
    const previousDate = this.toastTarget.dataset.previousDate
    if (!routeId || !previousDate) return

    this.hideToast()
    await this.persistRouteDate(routeId, previousDate)
    window.location.reload()
  }

  isPastDate(dateString) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const target = new Date(dateString)
    target.setHours(0, 0, 0, 0)
    return target < today
  }

  clearDragState() {
    if (this.draggedCard) {
      this.draggedCard.classList.remove("opacity-60")
    }
    this.dayTargets.forEach((day) => {
      day.classList.remove("ring-1", "ring-brand-primary")
    })
    this.draggedCard = null
  }
}
