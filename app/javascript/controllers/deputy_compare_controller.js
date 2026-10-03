import { Controller } from "@hotwired/stimulus"

// Seleciona deputados na listagem para compará-los lado a lado.
// A seleção fica no sessionStorage para sobreviver à troca de página/filtros.
const STORAGE_KEY = "deputy-compare"

export default class extends Controller {
  static targets = ["checkbox", "bar", "count", "link"]
  static values = { url: String, limit: { type: Number, default: 3 } }

  connect() {
    this.selected ??= this.load()
    this.render()
  }

  // Chamado quando o turbo frame recarrega os cards
  checkboxTargetConnected(checkbox) {
    this.selected ??= this.load()
    checkbox.checked = this.selected.includes(checkbox.value)
    this.syncDisabled()
  }

  toggle(event) {
    const id = event.target.value
    if (event.target.checked) {
      if (!this.selected.includes(id)) this.selected.push(id)
    } else {
      this.selected = this.selected.filter((selectedId) => selectedId !== id)
    }
    this.save()
    this.render()
  }

  clear() {
    this.selected = []
    this.save()
    this.checkboxTargets.forEach((checkbox) => (checkbox.checked = false))
    this.render()
  }

  render() {
    const count = this.selected.length
    this.barTarget.hidden = count === 0
    this.countTarget.textContent = count

    const params = new URLSearchParams()
    this.selected.forEach((id) => params.append("ids[]", id))
    this.linkTarget.href = `${this.urlValue}?${params}`
    this.linkTarget.classList.toggle("disabled", count < 2)

    this.syncDisabled()
  }

  syncDisabled() {
    const full = this.selected.length >= this.limitValue
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.disabled = full && !checkbox.checked
    })
  }

  load() {
    try {
      return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || []
    } catch {
      return []
    }
  }

  save() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(this.selected))
    } catch {
      // Sem storage disponível: a seleção vale só nesta página
    }
  }
}
