import { Controller } from "@hotwired/stimulus"

// Mapa de partidos: clicar num estado troca a lista para a bancada daquele estado;
// clicar de novo no mesmo estado, fora do mapa ou em "Ver Brasil" volta à visão nacional.
// Os dados de todos os estados vêm num JSON na própria página (são poucos), então trocar de
// estado não vai ao servidor. A UF escolhida vai para a URL (?uf=SP) para dar para compartilhar.
const percent = new Intl.NumberFormat("pt-BR", { style: "percent", maximumFractionDigits: 1 })

export default class extends Controller {
  static targets = ["data", "tile", "panel", "list", "row", "empty", "scope", "title", "summary", "reset"]
  static values = { selected: String }

  pick(event) {
    event.preventDefault() // espaço não rola a página
    event.stopPropagation() // não conta como clique fora do mapa
    const uf = event.currentTarget.dataset.uf
    this.selectedValue = this.selectedValue === uf ? "" : uf

    if (this.selectedValue && event.type === "click") this.revealPanel()
  }

  clickOutside(event) {
    if (!event.target.closest("[data-uf]")) this.clear()
  }

  clear() {
    this.selectedValue = ""
  }

  // Roda no connect (com o ?uf= vindo do servidor) e a cada troca de estado
  selectedValueChanged() {
    const state = this.mapData.states[this.selectedValue]

    this.tileTargets.forEach((tile) => {
      const active = tile.dataset.uf === this.selectedValue
      tile.classList.toggle("is-active", active)
      tile.setAttribute("aria-pressed", active)
    })
    this.element.classList.toggle("has-selection", Boolean(state))

    this.scopeTarget.textContent = state ? "Visão estadual" : "Visão nacional"
    this.titleTarget.textContent = state ? state.name : "Brasil"
    this.resetTarget.hidden = !state
    this.render(state ? state.seats : this.mapData.national)
    this.syncUrl()
  }

  get mapData() {
    return (this._mapData ??= JSON.parse(this.dataTarget.textContent))
  }

  render(seats) {
    const rows = Object.entries(seats)
      .map(([id, count]) => ({ party: this.mapData.parties[id], count }))
      .filter((row) => row.party)
      .sort((a, b) => b.count - a.count || a.party.label.localeCompare(b.party.label))

    const total = rows.reduce((sum, row) => sum + row.count, 0)
    const leader = rows[0]?.count || 1

    this.summaryTarget.textContent = total
      ? `${total} ${total === 1 ? "deputado" : "deputados"} · ${rows.length} ${rows.length === 1 ? "partido" : "partidos"}`
      : ""
    this.emptyTarget.hidden = total > 0
    this.listTarget.replaceChildren(...rows.map((row) => this.buildRow(row, total, leader)))
  }

  buildRow({ party, count }, total, leader) {
    const row = this.rowTarget.content.firstElementChild.cloneNode(true)
    const field = (name) => row.querySelector(`[data-field="${name}"]`)

    field("link").href = party.url
    field("label").textContent = party.label
    field("name").textContent = party.name
    field("pct").textContent = percent.format(count / total)
    field("seats").textContent = `${count} ${count === 1 ? "dep." : "deps."}`
    // A barra é relativa ao maior partido, para a diferença entre as bancadas ficar visível
    field("bar").style.width = `${(count / leader) * 100}%`
    return row
  }

  // No mobile o mapa fica em cima da lista: leva o usuário até os dados do estado
  revealPanel() {
    if (!window.matchMedia("(max-width: 991.98px)").matches) return

    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.panelTarget.scrollIntoView({ behavior: smooth ? "smooth" : "auto", block: "start" })
  }

  syncUrl() {
    const url = new URL(window.location.href)
    if (this.selectedValue) url.searchParams.set("uf", this.selectedValue)
    else url.searchParams.delete("uf")
    // Mantém o state do Turbo para o botão voltar continuar funcionando
    window.history.replaceState(window.history.state, "", url)
  }
}
