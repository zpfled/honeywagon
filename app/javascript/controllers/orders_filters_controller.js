import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["control"]

  submit() {
    this.element.requestSubmit()
  }

  enable() {
    this.controlTargets.forEach((control) => {
      control.disabled = false
    })
  }

  disable() {
    this.controlTargets.forEach((control) => {
      control.disabled = true
    })
  }
}
