import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("invisible")
    this.menuTarget.classList.toggle("opacity-0")
    this.menuTarget.classList.toggle("translate-y-1")
  }
}
