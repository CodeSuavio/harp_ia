import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-scroll"
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      this.element.scrollIntoView({ behavior: "smooth" })
    })
  }
}
