import { Controller } from "@hotwired/stimulus"

// Balões com seta apontando para os elementos da página, na primeira visita da sessão.
// Espera o "Como funciona" fechar quando ele estiver aberto.
const ONBOARDING_KEY = "harpia-onboarding-v1"

export default class extends Controller {
  static values = { key: String, steps: Array }

  connect() {
    this.Popover = window.bootstrap?.Popover
    if (!this.Popover || this.seen()) return

    this.onClick = this.onClick.bind(this)
    const modal = document.getElementById("onboarding-modal")
    if (modal && !this.onboardingSeen()) {
      modal.addEventListener("hidden.bs.modal", () => { this.timer = setTimeout(() => this.start(), 400) }, { once: true })
    } else {
      this.timer = setTimeout(() => this.start(), 700)
    }
  }

  disconnect() {
    clearTimeout(this.timer)
    this.finish()
  }

  start() {
    this.steps = this.stepsValue.filter((step) => document.querySelector(step.selector))
    if (this.steps.length === 0) return

    try { sessionStorage.setItem(this.storageKey, "1") } catch (_) {}
    document.addEventListener("click", this.onClick)
    this.index = 0
    this.show()
  }

  show() {
    this.clear()
    const step = this.steps[this.index]
    const target = document.querySelector(step.selector)
    if (!target) return this.next()

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    target.classList.add("tour-target")
    const popover = new this.Popover(target, {
      content: this.content(step.text),
      html: true,
      sanitize: false,
      trigger: "manual",
      placement: "bottom",
      fallbackPlacements: ["top", "right", "left"],
      customClass: "tour-popover"
    })
    this.current = { target, popover }
    this.showTimer = setTimeout(() => this.current?.popover.show(), 350)
  }

  next() {
    this.index += 1
    if (this.index >= this.steps.length) return this.finish()
    this.show()
  }

  onClick(event) {
    if (event.target.closest("[data-tour-next]")) { event.preventDefault(); this.next() }
    else if (event.target.closest("[data-tour-close]")) { event.preventDefault(); this.finish() }
  }

  clear() {
    clearTimeout(this.showTimer)
    if (!this.current) return
    this.current.popover.dispose()
    this.current.target.classList.remove("tour-target")
    this.current = null
  }

  finish() {
    this.clear()
    document.removeEventListener("click", this.onClick)
  }

  content(text) {
    const last = this.index === this.steps.length - 1
    const counter = this.steps.length > 1 ? `<span class="text-muted small">${this.index + 1} de ${this.steps.length}</span>` : "<span></span>"
    return `<div class="small mb-2">${text}</div>
      <div class="d-flex justify-content-between align-items-center gap-3">
        ${counter}
        <span class="text-nowrap">
          ${last ? "" : '<button type="button" class="btn btn-link btn-sm p-0 text-muted text-decoration-none me-3" data-tour-close>Pular</button>'}
          <button type="button" class="btn btn-sm btn-auth rounded-pill px-3" data-tour-next>${last ? "Entendi" : "Próximo"}</button>
        </span>
      </div>`
  }

  seen() {
    try { return sessionStorage.getItem(this.storageKey) === "1" } catch (_) { return true }
  }

  onboardingSeen() {
    try { return localStorage.getItem(ONBOARDING_KEY) === "1" } catch (_) { return true }
  }

  get storageKey() {
    return `harpia-tour:${this.keyValue}`
  }
}
