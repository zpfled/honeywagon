import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "street", "city", "state", "zip", "lat", "lng", "results", "placeId"]
  static values = {
    suggestionsUrl: String,
    detailsUrl: String
  }

  disconnect() {
    if (this.fetchTimeout) clearTimeout(this.fetchTimeout)
  }

  search(event) {
    const query = event.target.value.trim()
    this.clearPlaceId()
    if (this.fetchTimeout) clearTimeout(this.fetchTimeout)

    if (query.length < 3) {
      this.clearSuggestions()
      return
    }

    this.fetchTimeout = setTimeout(() => this.fetchSuggestions(query), 250)
  }

  fetchSuggestions(query) {
    if (!this.hasSuggestionsUrlValue) return

    const url = `${this.suggestionsUrlValue}?query=${encodeURIComponent(query)}`
    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data) => this.renderSuggestions(data.suggestions || []))
      .catch(() => this.clearSuggestions())
  }

  renderSuggestions(suggestions) {
    if (!this.hasResultsTarget) return
    if (suggestions.length === 0) {
      this.resultsTarget.innerHTML = ""
      const empty = document.createElement("div")
      empty.textContent = "No suggestions found"
      empty.className = "px-3 py-2 text-left text-sm text-gray-500"
      this.resultsTarget.appendChild(empty)
      this.resultsTarget.classList.remove("hidden")
      return
    }

    this.resultsTarget.innerHTML = ""
    suggestions.forEach((suggestion) => {
      const button = document.createElement("button")
      button.type = "button"
      button.textContent = suggestion.description
      button.dataset.placeId = suggestion.place_id || suggestion.placeId
      button.dataset.description = suggestion.description
      button.dataset.action = "click->address-autocomplete#selectSuggestion"
      button.className = "flex w-full items-center px-3 py-2 text-left hover:bg-gray-50 focus:bg-gray-100"
      this.resultsTarget.appendChild(button)
    })
    this.resultsTarget.classList.remove("hidden")
  }

  selectSuggestion(event) {
    event.preventDefault()
    const placeId = event.currentTarget.dataset.placeId
    const label = event.currentTarget.dataset.description

    if (this.hasSearchTarget && label) {
      this.searchTarget.value = label
    }

    if (this.hasPlaceIdTarget) {
      this.placeIdTarget.value = placeId || ""
    }

    this.clearSuggestions()
    if (placeId) this.fetchDetails(placeId)
  }

  fetchDetails(placeId) {
    if (!this.hasDetailsUrlValue) return

    const url = `${this.detailsUrlValue}?place_id=${encodeURIComponent(placeId)}`
    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((data) => this.populateFields(data))
      .catch(() => {})
  }

  populateFields(data) {
    if (this.hasStreetTarget && data.street) this.streetTarget.value = data.street
    if (this.hasCityTarget && data.city) this.cityTarget.value = data.city
    if (this.hasStateTarget && data.state) this.stateTarget.value = data.state
    if (this.hasZipTarget && data.postal_code) this.zipTarget.value = data.postal_code
    if (this.hasLatTarget && data.lat) this.latTarget.value = data.lat
    if (this.hasLngTarget && data.lng) this.lngTarget.value = data.lng
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.clearSuggestions()
    }
  }

  clearSuggestions() {
    if (!this.hasResultsTarget) return
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
  }

  clearPlaceId() {
    if (this.hasPlaceIdTarget) this.placeIdTarget.value = ""
  }
}
