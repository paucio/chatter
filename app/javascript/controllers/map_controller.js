import { Controller } from "@hotwired/stimulus"
import L from "leaflet"


export default class extends Controller {
  static targets = ["marker"]

  initialize() {
    this.map = L.map(this.element).setView([48.8, 10], 4)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    this.map.on("click", (event) => this.createChatroom(event))
  }

  markerTargetConnected(element) {
    const { chatroomId, latitude, longitude } = element.dataset

    const marker = L.marker([parseFloat(latitude), parseFloat(longitude)]).addTo(this.map)
    marker.on("click", (event) => {
      L.DomEvent.stopPropagation(event)
      document.getElementById("panel").src = `/chatrooms/${chatroomId}`
    })
  }

  createChatroom(event) {
    fetch("/chatrooms", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "",
        Accept: "text/vnd.turbo-stream.html",
      },
      body: JSON.stringify({
        chatroom: {
          latitude: event.latlng.lat,
          longitude: event.latlng.lng,
        },
      }),
    })
      .then((response) => response.text())
      .then((html) => Turbo.renderStreamMessage(html))
  }
}
