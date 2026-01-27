import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "map", "list", "mapButton", "listButton" ]
  static values = { default: String }

  connect() {
    const view = this.defaultValue || "map"
    this.show(view)
  }

  showMap() {
    this.show("map")
  }

  showList() {
    this.show("list")
  }

  show(view) {
    const showMap = view === "map"
    this.mapTarget.classList.toggle("hidden", !showMap)
    this.listTarget.classList.toggle("hidden", showMap)
    this.mapButtonTarget.classList.toggle("bg-gray-100", showMap)
    this.listButtonTarget.classList.toggle("bg-gray-100", !showMap)
    this.mapButtonTarget.classList.toggle("text-gray-900", showMap)
    this.listButtonTarget.classList.toggle("text-gray-900", !showMap)
    if (showMap) {
      this.dispatch("map-shown")
    }
  }
}
