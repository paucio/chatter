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
    fetch("/chatrooms", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "",
        Accept: "text/vnd.turbo-stream.html",
      },
      body: JSON.stringify({
        chatroom: { latitude: event.latlng.lat, longitude: event.latlng.lng },
      }),
    })
      .then((response) => response.text())
      .then((html) => Turbo.renderStreamMessage(html))
  }
}