import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Mapa de posicionamento (comparação de partidos): mostra os números da bolha
// mais próxima do cursor, sem exigir que a pessoa acerte bolhas pequenas.
// - mouse: passar pelo mapa destaca o partido mais perto; clicar abre o partido;
// - toque: o primeiro toque mostra o cartão; tocar de novo (ou no link do cartão) abre;
// - teclado: Tab passa pelas bolhas e mostra o mesmo cartão; Esc fecha.
// Sem JavaScript, cada bolha continua sendo um link com o <title> nativo.
const MAX_DISTANCE = 32 // em unidades do viewBox, além da borda da bolha

export default class extends Controller {
  static targets = ["svg", "point", "tooltip", "name", "fullName", "detail", "link"]

  connect() {
    // O cartão substitui o tooltip nativo, que demora a abrir e duplicaria a informação
    this.pointTargets.forEach((point) => point.querySelector("title")?.remove())
    this.lastPointer = "mouse"
  }

  pointerdown(event) {
    this.lastPointer = event.pointerType || "mouse"
  }

  move(event) {
    if (event.pointerType === "touch" || this.pinned) return
    this.activate(this.nearest(event))
  }

  leave() {
    if (!this.pinned) this.deactivate()
  }

  // Clique ou toque em qualquer ponto do mapa
  click(event) {
    const point = this.nearest(event)
    if (!point) {
      this.deactivate()
      return
    }

    if (this.lastPointer === "touch" && point !== this.active) {
      // Primeiro toque: só mostra os números
      event.preventDefault()
      this.activate(point)
      this.pin()
      return
    }

    // Clique fora da bolha (mas perto dela) também abre o partido; na bolha, o próprio link abre
    if (!event.target.closest("a")) Turbo.visit(point.getAttribute("href"))
  }

  focus(event) {
    this.activate(event.target.closest("[data-positioning-chart-target='point']"))
  }

  blur() {
    if (!this.pinned) this.deactivate()
  }

  // Fixado por um toque, o cartão aceita clique (no link "Abrir o partido")
  pin() {
    this.pinned = true
    this.tooltipTarget.classList.add("is-pinned")
  }

  close() {
    this.pinned = false
    this.deactivate()
  }

  // ----- AUXILIARES -----

  // Com o cursor dentro de uma ou mais bolhas, a menor delas: é a desenhada por cima
  // (ex.: REDE dentro do PT). Fora das bolhas, a de borda mais perto, até MAX_DISTANCE.
  nearest(event) {
    const cursor = this.toSvg(event)
    let inside = null
    let insideRadius = Infinity
    let closest = null
    let closestDistance = MAX_DISTANCE

    this.pointTargets.forEach((point) => {
      const dot = point.querySelector(".dot")
      const radius = dot.r.baseVal.value
      const distance = Math.hypot(dot.cx.baseVal.value - cursor.x, dot.cy.baseVal.value - cursor.y) - radius

      if (distance <= 0 && radius < insideRadius) {
        inside = point
        insideRadius = radius
      } else if (distance > 0 && distance < closestDistance) {
        closest = point
        closestDistance = distance
      }
    })
    return inside || closest
  }

  toSvg(event) {
    const svg = this.svgTarget
    const point = svg.createSVGPoint()
    point.x = event.clientX
    point.y = event.clientY
    return point.matrixTransform(svg.getScreenCTM().inverse())
  }

  activate(point) {
    if (!point) {
      this.deactivate()
      return
    }
    if (point === this.active) return

    this.active?.classList.remove("is-active")
    this.active = point
    point.classList.add("is-active")
    this.svgTarget.classList.add("has-active")

    const data = point.dataset
    this.nameTarget.textContent = data.label
    this.fullNameTarget.textContent = data.name
    const lines = [data.seats, data.bloc, data.governism, data.cohesion].filter(Boolean).map((line) => {
      const item = document.createElement("li")
      item.textContent = line
      return item
    })
    // Bolhas que se cobrem: avisa, porque a menor nem sempre tem rótulo visível
    if (data.overlaps) {
      const item = document.createElement("li")
      item.className = "positioning-tooltip-overlaps"
      item.textContent = `Sobreposto a: ${data.overlaps}`
      lines.push(item)
    }
    this.detailTarget.replaceChildren(...lines)
    this.linkTarget.href = point.getAttribute("href")
    this.tooltipTarget.hidden = false
    this.position(point)
  }

  deactivate() {
    this.active?.classList.remove("is-active")
    this.active = null
    this.pinned = false
    this.tooltipTarget.classList.remove("is-pinned")
    this.svgTarget.classList.remove("has-active")
    this.tooltipTarget.hidden = true
  }

  // Cartão acima da bolha (ou abaixo, se não couber), sem sair da área do mapa
  position(point) {
    const area = this.tooltipTarget.offsetParent.getBoundingClientRect()
    const dot = point.querySelector(".dot").getBoundingClientRect()
    const tooltip = this.tooltipTarget
    const gap = 10

    let left = dot.left + dot.width / 2 - area.left - tooltip.offsetWidth / 2
    left = Math.max(4, Math.min(left, area.width - tooltip.offsetWidth - 4))

    let top = dot.top - area.top - tooltip.offsetHeight - gap
    if (top < 0) top = dot.bottom - area.top + gap

    tooltip.style.left = `${left}px`
    tooltip.style.top = `${top}px`
  }
}
