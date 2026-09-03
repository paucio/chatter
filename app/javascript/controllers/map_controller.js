import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Connects to data-controller="map"
export default class extends Controller {
  static targets = ["marker"]

  connect() {
    this.map = L.map(this.element).setView([48.8, 10], 4)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    this.map.on("click", this.createChatroom)

    // Targets that connected before the map existed.
    this.markerTargets.forEach((element) => this.#addMarker(element))
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }

  markerTargetConnected(element) {
    this.#addMarker(element)
  }

  #addMarker(element) {
    if (!this.map) return // connect() will sweep it

    const { chatroomId, latitude, longitude } = element.dataset
    const marker = L.marker([parseFloat(latitude), parseFloat(longitude)]).addTo(this.map)
    marker.on("click", (event) => {
      L.DomEvent.stopPropagation(event)
      document.getElementById("panel").src = `/chatrooms/${chatroomId}`
    })
  }

  createChatroom = (event) => {
    const form = document.getElementById("new-chatroom-form")
    document.getElementById("new-chatroom-latitude").value  = event.latlng.lat
    document.getElementById("new-chatroom-longitude").value = event.latlng.lng
    form.requestSubmit()
  }
}