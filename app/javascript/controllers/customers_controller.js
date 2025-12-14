import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const index = this.listTarget.querySelectorAll("[data-customer-entry]").length
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", index)
    const template = document.createElement("template")
    template.innerHTML = html.trim()
    this.listTarget.appendChild(template.content)
  }
}
