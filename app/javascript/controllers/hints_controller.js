import { Controller } from "@hotwired/stimulus"

// Dicas localizadas. O ponto fica até a pessoa tocar em "Entendi" ou usar o recurso.
// O X do balão desliga todas as dicas daquela página; "Rever dicas" no rodapé religa tudo.
const STORAGE_KEY = "harpia-hints-v1"
const ONBOARDING_KEY = "harpia-onboarding-v1"
const MAX_BEACONS = 3
const NAVBAR = 76
const INLINE = "h1, h2, h3, h4, h5, h6"
const FOCUSABLE = "a[href], button, input, select, textarea, summary, [tabindex]"

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
    document.querySelectorAll(".hint-beacon, .hint-toast").forEach((stale) => stale.remove())
    if (!this.Popover) return

    this.modal = document.getElementById("onboarding-modal")
    if (this.modal && !this.onboardingSeen()) {
      this.afterOnboarding = () => { this.timer = setTimeout(() => this.start(), 600) }
      this.modal.addEventListener("hidden.bs.modal", this.afterOnboarding, { once: true })
    } else {
      this.timer = setTimeout(() => this.start(), 800)
    }
  }

  disconnect() {
    this.cleanup()
    this.modal?.removeEventListener("hidden.bs.modal", this.afterOnboarding)
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
    pending
      .filter((item) => item.mode !== "auto" && item.target.getClientRects().length > 0)
      .slice(0, MAX_BEACONS)
      .forEach((item) => this.addBeacon(item))
    this.pulseFirst()
    return pending
  }

  // Com "contains", fica o elemento mais interno que tem o texto
  find(item) {
    let nodes
    try { nodes = [...document.querySelectorAll(item.selector)] } catch (_) { return null }
    if (item.contains) nodes = nodes.filter((node) => node.textContent.includes(item.contains))
    return nodes.find((node) => !nodes.some((other) => other !== node && node.contains(other)))
  }

  // Balão automático: abre quando a maior parte do recurso está na tela
  watch(item) {
    const observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return

      clearTimeout(this.autoTimer)
      this.autoTimer = setTimeout(() => {
        if (this.current || this.blocked() || this.seen(item.id) || this.pageOff() || !this.visible(item.target)) return
        observer.disconnect()
        this.open(item, { auto: true })
      }, 800)
    }, { threshold: [0, 0.3, 0.6, 1] })
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

    item.inline = item.target.matches(INLINE)
    if (item.inline) {
      beacon.classList.add("hint-beacon--inline")
      item.target.appendChild(beacon)
    } else {
      const host = item.target.parentElement
      if (getComputedStyle(host).position === "static") {
        host.classList.add("has-hint-beacon")
        item.host = host
      }
      item.target.insertAdjacentElement("afterend", beacon)
    }

    item.beacon = beacon
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

  // Ponto no canto superior direito do recurso, sem passar da borda da tela
  place(item) {
    const { target, beacon, inline } = item
    if (!beacon || inline) return

    // Em selo e legenda (baixos), o ponto vai acima do texto, como expoente, para não cobrir o número
    const half = beacon.offsetWidth / 2
    const room = document.documentElement.clientWidth - target.getBoundingClientRect().right
    const small = target.offsetHeight < 28
    const shift = Math.min(small ? 6 : 2, room - half - 4)
    beacon.style.left = `${target.offsetLeft + target.offsetWidth + shift}px`
    beacon.style.top = `${target.offsetTop + (small ? 0 : 6)}px`
  }

  pulseFirst() {
    this.beacons.forEach((item, index) => item.beacon?.classList.toggle("hint-beacon--pulse", index === 0))
  }

  open(item, { auto = false } = {}) {
    this.close()
    const { target } = item
    const popover = new this.Popover(target, {
      content: this.content(item),
      html: true,
      sanitize: false,
      animation: false,
      trigger: "manual",
      placement: "bottom",
      fallbackPlacements: ["top", "bottom"],
      offset: [0, 12],
      customClass: "hint-pop",
      template: `<div class="popover hint-pop" role="dialog" aria-label="Dica: ${this.escape(item.label)}"><div class="popover-arrow"></div><div class="popover-body"></div></div>`,
      popperConfig: (config) => ({
        ...config,
        modifiers: [
          ...config.modifiers,
          { name: "preventOverflow", options: { padding: { top: NAVBAR, right: 12, bottom: 96, left: 12 } } },
          { name: "flip", options: { padding: { top: NAVBAR, bottom: 96 } } },
          { name: "arrow", options: { padding: 14 } }
        ]
      })
    })
    target.classList.add("hint-target")
    item.beacon?.setAttribute("aria-expanded", "true")
    item.beacon?.classList.add("is-open")
    this.current = { item, popover }
    if (auto) this.remember(item.id)

    if (!auto) {
      target.addEventListener("shown.bs.popover", () => popover.tip?.querySelector("[data-hint='done']")?.focus({ preventScroll: true }), { once: true })
    }
    popover.show()
  }

  // Fecha o balão; o ponto continua lá até "Entendi"
  close() {
    if (!this.current) return

    const { item, popover } = this.current
    const hadFocus = popover.tip?.contains(document.activeElement)
    this.current = null
    popover.hide()
    popover.dispose()
    item.target.classList.remove("hint-target")
    item.beacon?.setAttribute("aria-expanded", "false")
    item.beacon?.classList.remove("is-open")
    if (hadFocus) this.focusBack(item)
  }

  done(item) {
    this.remember(item.id)
    const wasOpen = this.current?.item === item
    const hadFocus = wasOpen && this.current.popover.tip?.contains(document.activeElement)
    if (wasOpen) this.close()
    this.removeBeacon(item)
    if (hadFocus) this.focusBack(item)
  }

  focusBack(item) {
    if (item.beacon?.isConnected) return item.beacon.focus({ preventScroll: true })

    const { target } = item
    if (!target.isConnected) return
    if (!target.matches(FOCUSABLE)) target.setAttribute("tabindex", "-1")
    target.focus({ preventScroll: true })
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
    this.showUndo()
  }

  // Confirma o X e permite desfazer
  showUndo() {
    const toast = document.createElement("div")
    toast.className = "hint-toast"
    toast.setAttribute("role", "status")
    toast.innerHTML = `<span>Dicas desta página desligadas.</span>
      <button type="button" class="hint-toast-undo" data-hint="undo">Desfazer</button>`
    document.body.appendChild(toast)
    this.toast = toast
    this.toastTimer = setTimeout(() => toast.remove(), 6000)
  }

  undo() {
    const state = this.load()
    delete state.off[this.pageValue]
    this.save(state)
    this.removeToast()
    this.start()
  }

  removeToast() {
    clearTimeout(this.toastTimer)
    this.toast?.remove()
    this.toast = null
  }

  reset(link) {
    try { localStorage.removeItem(STORAGE_KEY) } catch (_) {}
    const pending = this.start()
    const original = link.dataset.label || link.textContent
    link.dataset.label = original
    link.textContent = pending.length ? "Dicas reativadas" : "Esta página não tem dicas"
    clearTimeout(this.labelTimer)
    this.labelTimer = setTimeout(() => { link.textContent = original }, 2500)

    const first = this.beacons[0]
    if (!first) return
    first.target.scrollIntoView({ behavior: "smooth", block: "center" })
    this.resetTimer = setTimeout(() => { if (first.beacon?.isConnected) this.open(first) }, 450)
  }

  onClick(event) {
    const reset = event.target.closest("[data-hints-reset]")
    if (reset) { event.preventDefault(); return this.reset(reset) }
    if (event.target.closest("[data-hint='undo']")) return this.undo()

    const tip = this.current?.popover.tip
    if (!tip) return
    if (event.target.closest("[data-hint='off']")) return this.turnOffPage()
    if (event.target.closest("[data-hint='done']")) return this.done(this.current.item)
    if (!tip.contains(event.target) && !event.target.closest(".hint-beacon")) this.close()
  }

  onKey(event) {
    if (event.key === "Escape" && this.current) this.close()
  }

  onResize() {
    this.beacons.forEach((item) => this.place(item))
  }

  cleanup() {
    clearTimeout(this.timer)
    clearTimeout(this.autoTimer)
    clearTimeout(this.resetTimer)
    this.close()
    this.beacons.slice().forEach((item) => this.removeBeacon(item))
    this.observers.forEach((observer) => observer.disconnect())
    this.observers = []
  }

  blocked() {
    if (document.querySelector(".modal.show, .offcanvas.show")) return true
    const chat = document.querySelector(".chat-widget-window")
    return !!(chat && chat.getClientRects().length > 0 && getComputedStyle(chat).visibility !== "hidden")
  }

  // Ao menos 60% do recurso (ou da tela, se ele for maior que ela) abaixo da barra de navegação
  visible(element) {
    const rect = element.getBoundingClientRect()
    const top = Math.max(rect.top, NAVBAR)
    const bottom = Math.min(rect.bottom, window.innerHeight)
    const shown = bottom - top
    return rect.height > 0 && shown / Math.min(rect.height, window.innerHeight - NAVBAR) >= 0.6
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
    return span.innerHTML.replace(/"/g, "&quot;")
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
