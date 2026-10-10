import { Controller } from "@hotwired/stimulus"

// Abre o "Como funciona" na primeira visita; depois só pelo link do rodapé
const STORAGE_KEY = "harpia-onboarding-v1"

export default class extends Controller {
  connect() {
    const Modal = window.bootstrap?.Modal
    if (!Modal || this.seen()) return

    this.timer = setTimeout(() => Modal.getOrCreateInstance(this.element).show(), 600)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  remember() {
    try { localStorage.setItem(STORAGE_KEY, "1") } catch (_) {}
  }

  seen() {
    try { return localStorage.getItem(STORAGE_KEY) === "1" } catch (_) { return true }
  }
}
