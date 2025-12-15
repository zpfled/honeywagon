import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customer", "location", "locationLink"]
  static values = {
    locationUrl: String
  }

  connect() {
    this.update()
  }

  customerChanged() {
    this.update()
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
}
