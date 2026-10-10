import { Controller } from "@hotwired/stimulus"

// Dicas localizadas. Cada uma aparece até a pessoa fechar ou usar o recurso.
// O X do balão desliga todas as dicas daquela página; "Rever dicas" no rodapé religa tudo.
const STORAGE_KEY = "harpia-hints-v1"
const ONBOARDING_KEY = "harpia-onboarding-v1"
const MAX_BEACONS = 3
const INSIDE = "summary, h1, h2, h3, h4, h5, h6"
const TEMPLATE = (role) =>
  `<div class="popover hint-pop" role="${role}"><div class="popover-arrow"></div><div class="popover-body"></div></div>`

export default class extends Controller {
  static values = { page: String, items: Array }

  connect() {
    this.Popover = window.bootstrap?.Popover
    this.beacons = []
    this.observers = []
    this.cleanup = this.cleanup.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onResize = this.onResize.bind(this)
    document.addEventListener("turbo:before-cache", this.cleanup)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKey)
    window.addEventListener("resize", this.onResize)
    document.querySelectorAll(".hint-beacon").forEach((stale) => stale.remove())
    if (!this.Popover) return

    const modal = document.getElementById("onboarding-modal")
    if (modal && !this.onboardingSeen()) {
      modal.addEventListener("hidden.bs.modal", () => { this.timer = setTimeout(() => this.start(), 600) }, { once: true })
    } else {
      this.timer = setTimeout(() => this.start(), 800)
    }
  }

  disconnect() {
    this.cleanup()
    document.removeEventListener("turbo:before-cache", this.cleanup)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKey)
    window.removeEventListener("resize", this.onResize)
  }

  start() {
    this.cleanup()
    if (this.pageOff()) return []

    const pending = this.itemsValue
      .filter((item) => !this.seen(item.id))
      .map((item) => ({ ...item, target: this.find(item) }))
      .filter((item) => item.target)

    pending.filter((item) => item.mode === "auto").forEach((item) => this.watch(item))
    pending.filter((item) => item.mode !== "auto").slice(0, MAX_BEACONS).forEach((item) => this.addBeacon(item))
    this.pulseFirst()
    return pending
  }

  find(item) {
    return [...document.querySelectorAll(item.selector)]
      .find((node) => !item.contains || node.textContent.includes(item.contains))
  }

  // Balão automático: só quando o recurso estiver de fato visível
  watch(item) {
    const observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return

      clearTimeout(this.autoTimer)
      this.autoTimer = setTimeout(() => {
        if (this.current || this.blocked() || this.seen(item.id) || this.pageOff() || !this.visible(item.target)) return
        observer.disconnect()
        this.open(item, { auto: true })
      }, 800)
    }, { threshold: 0.6 })
    observer.observe(item.target)
    this.observers.push(observer)
    this.listenForUse(item)
  }

  addBeacon(item) {
    const beacon = document.createElement("button")
    beacon.type = "button"
    beacon.className = "hint-beacon"
    beacon.setAttribute("aria-label", `Dica: ${item.label}`)
    beacon.setAttribute("aria-expanded", "false")
    beacon.addEventListener("click", (event) => {
      event.preventDefault()
      event.stopPropagation()
      this.current?.item === item ? this.close() : this.open(item)
    })

    const inside = item.target.matches(INSIDE)
    const host = inside ? item.target : item.target.parentElement
    if (getComputedStyle(host).position === "static") {
      host.classList.add("has-hint-beacon")
      item.host = host
    }
    inside ? item.target.appendChild(beacon) : item.target.insertAdjacentElement("afterend", beacon)

    item.beacon = beacon
    item.inside = inside
    this.beacons.push(item)
    this.place(item)
    this.listenForUse(item)
  }

  // Quem usa o recurso antes de abrir a dica não precisa mais dela
  listenForUse(item) {
    item.onUse = () => this.done(item)
    const event = item.target.matches("select, input") ? "change" : "click"
    item.target.addEventListener(event, item.onUse, { once: true })
  }

  place(item) {
    const { target, beacon, inside } = item
    if (!beacon) return

    const left = (inside ? 0 : target.offsetLeft) + target.offsetWidth - 4
    const top = (inside ? 0 : target.offsetTop) + 4
    beacon.style.left = `${left}px`
    beacon.style.top = `${top}px`
  }

  pulseFirst() {
    this.beacons.forEach((item, index) => item.beacon?.classList.toggle("hint-beacon--pulse", index === 0))
  }

  open(item, { auto = false } = {}) {
    this.close()
    const { target } = item
    target.classList.add("hint-target")
    const popover = new this.Popover(target, {
      content: this.content(item),
      html: true,
      sanitize: false,
      trigger: "manual",
      placement: "bottom",
      fallbackPlacements: ["top", "bottom"],
      offset: [0, 12],
      customClass: "hint-pop",
      template: TEMPLATE(auto ? "status" : "dialog"),
      popperConfig: (config) => ({
        ...config,
        modifiers: [
          ...config.modifiers,
          { name: "preventOverflow", options: { padding: { top: 76, right: 12, bottom: 96, left: 12 } } },
          { name: "arrow", options: { padding: 14 } }
        ]
      })
    })
    item.beacon?.setAttribute("aria-expanded", "true")
    this.current = { item, popover }
    this.remember(item.id)

    if (!auto) {
      target.addEventListener("shown.bs.popover", () => popover.tip?.querySelector("[data-hint='done']")?.focus({ preventScroll: true }), { once: true })
    }
    popover.show()
  }

  close() {
    if (!this.current) return

    const { item, popover } = this.current
    this.current = null
    popover.dispose()
    item.target.classList.remove("hint-target")
    this.removeBeacon(item)
  }

  done(item) {
    this.remember(item.id)
    this.current?.item === item ? this.close() : this.removeBeacon(item)
  }

  removeBeacon(item) {
    if (!item.beacon) return

    item.beacon.remove()
    item.beacon = null
    item.host?.classList.remove("has-hint-beacon")
    this.beacons = this.beacons.filter((other) => other !== item)
    this.pulseFirst()
  }

  turnOffPage() {
    const state = this.load()
    state.off[this.pageValue] = 1
    this.save(state)
    this.cleanup()
  }

  reset(link) {
    try { localStorage.removeItem(STORAGE_KEY) } catch (_) {}
    const pending = this.start()
    const original = link.dataset.label || link.textContent
    link.dataset.label = original
    link.textContent = pending.length ? "Dicas reativadas" : "Esta página não tem dicas"
    setTimeout(() => { link.textContent = original }, 2500)

    const first = this.beacons[0]
    if (!first) return
    first.target.scrollIntoView({ behavior: "smooth", block: "center" })
    setTimeout(() => this.open(first), 450)
  }

  onClick(event) {
    const reset = event.target.closest("[data-hints-reset]")
    if (reset) { event.preventDefault(); return this.reset(reset) }

    const tip = this.current?.popover.tip
    if (!tip) return
    if (event.target.closest("[data-hint='off']")) return this.turnOffPage()
    if (event.target.closest("[data-hint='done']")) return this.close()
    if (!tip.contains(event.target) && !event.target.closest(".hint-beacon")) this.close()
  }

  onKey(event) {
    if (event.key !== "Escape" || !this.current) return

    const { target } = this.current.item
    this.close()
    target.focus?.({ preventScroll: true })
  }

  onResize() {
    this.beacons.forEach((item) => this.place(item))
  }

  cleanup() {
    clearTimeout(this.timer)
    clearTimeout(this.autoTimer)
    this.close()
    this.beacons.slice().forEach((item) => this.removeBeacon(item))
    this.observers.forEach((observer) => observer.disconnect())
    this.observers = []
  }

  blocked() {
    if (document.querySelector(".modal.show, .offcanvas.show")) return true
    const chat = document.querySelector(".chat-widget-window")
    return !!(chat && chat.offsetParent)
  }

  visible(element) {
    const rect = element.getBoundingClientRect()
    return rect.width > 0 && rect.top >= 0 && rect.bottom <= window.innerHeight
  }

  content(item) {
    return `<button type="button" class="hint-off" data-hint="off" aria-label="Desligar as dicas desta página" title="Desligar as dicas desta página">
        <i class="fa-solid fa-xmark" aria-hidden="true"></i>
      </button>
      <p class="hint-text">${this.escape(item.text)}</p>
      <div class="hint-actions">
        <button type="button" class="hint-btn" data-hint="done">Entendi</button>
      </div>`
  }

  escape(text) {
    const span = document.createElement("span")
    span.textContent = text
    return span.innerHTML
  }

  load() {
    try {
      const state = JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}
      return { seen: state.seen || {}, off: state.off || {} }
    } catch (_) {
      return { seen: {}, off: {} }
    }
  }

  save(state) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)) } catch (_) {}
  }

  seen(id) {
    return !!this.load().seen[id]
  }

  remember(id) {
    const state = this.load()
    state.seen[id] = 1
    this.save(state)
  }

  pageOff() {
    return !!this.load().off[this.pageValue]
  }

  onboardingSeen() {
    try { return localStorage.getItem(ONBOARDING_KEY) === "1" } catch (_) { return true }
  }
}
