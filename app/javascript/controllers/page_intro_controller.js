import { Controller } from "@hotwired/stimulus"

// Mostra a explicação da página só na primeira visita da sessão (até fechar o navegador)
export default class extends Controller {
  static values = { key: String }

  connect() {
    if (this.seen()) return

    this.element.classList.remove("d-none")
    try { sessionStorage.setItem(this.storageKey, "1") } catch (_) {}
  }

  dismiss() {
    this.element.remove()
  }

  seen() {
    try { return sessionStorage.getItem(this.storageKey) === "1" } catch (_) { return true }
  }

  get storageKey() {
    return `harpia-intro:${this.keyValue}`
  }
}
