import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.body.classList.add("overflow-hidden")
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }

  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.clearFrame()
  }

  maybeClose(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }

  clearFrame() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }
}
