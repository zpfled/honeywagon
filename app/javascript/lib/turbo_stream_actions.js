import { Turbo } from "@hotwired/turbo-rails"

Turbo.StreamActions.dispatch_event = function () {
  const eventName = this.getAttribute("event")
  if (!eventName) return

  let detail = {}
  const payload = this.getAttribute("payload")
  if (payload) {
    try {
      detail = JSON.parse(payload)
    } catch (error) {
      detail = { payload }
    }
  }

  const event = new CustomEvent(eventName, { detail })
  window.dispatchEvent(event)
}
