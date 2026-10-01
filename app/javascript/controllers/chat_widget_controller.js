import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-widget"
export default class extends Controller {
   static targets = ["button", "window"]

  connect() {
    this.windowTarget.hidden = true
  }

  open() {
    this.buttonTarget.hidden = true
    this.windowTarget.hidden = false
  }

  close() {
    this.windowTarget.hidden = true
    this.buttonTarget.hidden = false
  }

}
