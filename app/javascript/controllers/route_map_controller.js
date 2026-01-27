import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    apiKey: String,
    stops: Array
  }

  connect() {
    this.map = null
    this.bounds = null
    this.loadMap()
  }

  disconnect() {
    this.map = null
    this.bounds = null
  }

  async loadMap() {
    if (!this.apiKeyValue) {
      this.showStatus("Google Maps API key is missing.")
      return
    }

    try {
      await this.loadGoogleMaps()
      this.renderMap()
    } catch (_error) {
      this.showStatus("Unable to load Google Maps. Check the API key and network.")
    }
  }

  async loadGoogleMaps() {
    if (window.google && window.google.maps) return

    if (!this.constructor.googleMapsPromise) {
      this.constructor.googleMapsPromise = new Promise((resolve, reject) => {
        window.__routeMapInit = () => resolve()
        const script = document.createElement("script")
        script.async = true
        script.defer = true
        script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}&callback=__routeMapInit`
        script.onerror = reject
        document.head.appendChild(script)
      })
    }

    return this.constructor.googleMapsPromise
  }

  renderMap() {
    const stops = this.resolveStops()
    if (!stops.length) {
      this.showStatus("No stops with coordinates to map.")
      return
    }

    this.map = new google.maps.Map(this.element, {
      zoom: 11,
      center: { lat: stops[0].lat, lng: stops[0].lng },
      mapTypeControl: false,
      fullscreenControl: true,
      streetViewControl: false
    })

    this.bounds = new google.maps.LatLngBounds()
    const infoWindow = new google.maps.InfoWindow()

    stops.forEach((stop) => {
      const position = { lat: stop.lat, lng: stop.lng }
      this.bounds.extend(position)
      const marker = new google.maps.Marker({
        position,
        map: this.map,
        label: {
          text: String(stop.number),
          color: "#111827",
          fontSize: "12px",
          fontWeight: "600"
        },
        title: stop.label || `Stop ${stop.number}`
      })

      marker.addListener("mouseover", () => {
        const subtitle = stop.location_label ? `<div class="text-xs text-gray-600">${stop.location_label}</div>` : ""
        infoWindow.setContent(`
          <div class="text-sm font-semibold text-gray-900">Stop ${stop.number}: ${stop.label || ""}</div>
          ${subtitle}
        `)
        infoWindow.open(this.map, marker)
      })

      marker.addListener("mouseout", () => {
        infoWindow.close()
      })
    })

    if (stops.length > 1) {
      this.map.fitBounds(this.bounds, 60)
    } else {
      this.map.setZoom(13)
    }
  }

  resolveStops() {
    if (Array.isArray(this.stopsValue) && this.stopsValue.length) {
      return this.stopsValue
    }

    const raw = this.element.dataset.routeMapStopsValue
    if (!raw) return []

    try {
      const parsed = JSON.parse(raw)
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return []
    }
  }

  refresh() {
    if (!this.map || !this.bounds) return
    google.maps.event.trigger(this.map, "resize")
    if (this.bounds.isEmpty()) return
    this.map.fitBounds(this.bounds, 60)
  }

  showStatus(message) {
    this.element.innerHTML = `<div class="flex h-full w-full items-center justify-center text-sm text-gray-500">${message}</div>`
  }
}
