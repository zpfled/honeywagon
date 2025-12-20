import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customer", "location", "locationLink", "startDate", "endDate", "availability"]
  static values = {
    locationUrl: String,
    availabilityUrl: String
  }

  connect() {
    this.update()
    this.fetchAvailability()
  }

  customerChanged() {
    this.update()
  }

  datesChanged() {
    this.fetchAvailability()
  }

  update() {
    const customerId = this.hasCustomerTarget ? this.customerTarget.value : null
    const hasCustomer = customerId && customerId.length > 0

    if (this.hasLocationTarget) {
      this.locationTarget.disabled = !hasCustomer
      if (!hasCustomer) this.locationTarget.value = ""
    }

    if (this.hasLocationLinkTarget) {
      this.locationLinkTarget.classList.toggle("opacity-50", !hasCustomer)
      this.locationLinkTarget.classList.toggle("pointer-events-none", !hasCustomer)

      if (hasCustomer) {
        const baseUrl = this.locationUrlValue || this.locationLinkTarget.getAttribute("href")
        const url = new URL(baseUrl, window.location.origin)
        url.searchParams.set("customer_id", customerId)
        this.locationLinkTarget.href = `${url.pathname}?${url.searchParams.toString()}`
        this.locationLinkTarget.dataset.turboFrame = "location_modal"
      } else {
        this.locationLinkTarget.href = "#"
        delete this.locationLinkTarget.dataset.turboFrame
      }
    }
  }

  fetchAvailability() {
    if (!this.hasAvailabilityTarget || !this.hasAvailabilityUrlValue) return

    const start = this.hasStartDateTarget ? this.startDateTarget.value : null
    const end = this.hasEndDateTarget ? this.endDateTarget.value : null

    if (!start || !end) {
      this.showAvailabilityMessage("Select start and end dates to see availability.")
      return
    }

    this.showAvailabilityMessage("Checking availability…")

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    const url = new URL(this.availabilityUrlValue, window.location.origin)
    url.searchParams.set("start_date", start)
    url.searchParams.set("end_date", end)

    fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) {
          return response.json().then((data) => Promise.reject(data)).catch(() => Promise.reject({ error: "Unable to load availability." }))
        }
        return response.json()
      })
      .then((data) => this.renderAvailability(data.availability || []))
      .catch((error) => {
        if (error?.name === "AbortError") return
        const message = error?.error || "Unable to load availability."
        this.showAvailabilityMessage(message, "text-rose-600")
      })
  }

  renderAvailability(entries) {
    if (!entries.length) {
      this.showAvailabilityMessage("No units available for this window.", "text-amber-600")
      return
    }

    this.availabilityTarget.innerHTML = ""
    const list = document.createElement("div")
    list.className = "space-y-2"

    entries.forEach((entry) => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between text-sm text-gray-900"

      const name = document.createElement("span")
      name.textContent = entry.name

      const count = document.createElement("span")
      count.className = `font-semibold ${entry.available > 0 ? "text-gray-900" : "text-rose-600"}`
      count.textContent = `${entry.available} available`

      row.appendChild(name)
      row.appendChild(count)
      list.appendChild(row)
    })

    this.availabilityTarget.appendChild(list)
  }

  showAvailabilityMessage(message, toneClass = "text-gray-600") {
    if (!this.hasAvailabilityTarget) return
    this.availabilityTarget.innerHTML = ""
    const p = document.createElement("p")
    p.className = `text-sm ${toneClass}`
    p.textContent = message
    this.availabilityTarget.appendChild(p)
  }
}
