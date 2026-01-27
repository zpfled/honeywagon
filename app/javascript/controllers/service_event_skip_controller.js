import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "reason" ]
  static values = { url: String }

  submit(event) {
    event.preventDefault()

    const reason = this.reasonTarget.value.trim()
    if (!reason) {
      this.reasonTarget.focus()
      return
    }

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue
    form.style.display = "none"

    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token) {
      const tokenInput = document.createElement("input")
      tokenInput.type = "hidden"
      tokenInput.name = "authenticity_token"
      tokenInput.value = token
      form.appendChild(tokenInput)
    }

    const reasonInput = document.createElement("input")
    reasonInput.type = "hidden"
    reasonInput.name = "skip_reason"
    reasonInput.value = reason
    form.appendChild(reasonInput)

    document.body.appendChild(form)
    form.submit()
  }
}
