import { Controller } from "@hotwired/stimulus"

// Seleciona deputados na listagem para compará-los lado a lado.
// As caixas "Comparar" só aparecem com o modo de comparação ativo (botão abaixo dos filtros).
// Modo e seleção ficam no sessionStorage para sobreviver à troca de página/filtros.
const STORAGE_KEY = "deputy-compare"
const MODE_KEY = "deputy-compare-mode"

export default class extends Controller {
  static targets = ["checkbox", "bar", "count", "link", "modeButton", "modeLabel"]
  static values = { url: String, limit: { type: Number, default: 3 } }

  connect() {
    this.selected ??= this.load()
    this.active ??= this.selected.length > 0 || this.read(MODE_KEY) === true
    this.render()
  }

  // Chamado quando o turbo frame recarrega os cards
  checkboxTargetConnected(checkbox) {
    this.selected ??= this.load()
    checkbox.checked = this.selected.includes(checkbox.value)
    this.syncDisabled()
  }

  // O botão fica dentro do turbo frame e é recriado a cada filtro
  modeButtonTargetConnected() {
    this.renderMode()
  }

  toggleMode() {
    this.active = !this.active
    // Sair do modo cancela a comparação
    if (!this.active) this.clear()
    this.write(MODE_KEY, this.active)
    this.render()
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
    this.barTarget.hidden = !this.active || count === 0
    this.countTarget.textContent = count

    const params = new URLSearchParams()
    this.selected.forEach((id) => params.append("ids[]", id))
    this.linkTarget.href = `${this.urlValue}?${params}`
    this.linkTarget.classList.toggle("disabled", count < 2)

    this.renderMode()
    this.syncDisabled()
  }

  renderMode() {
    this.element.classList.toggle("is-comparing", !!this.active)
    if (!this.hasModeButtonTarget) return

    this.modeButtonTarget.setAttribute("aria-pressed", String(!!this.active))
    this.modeLabelTarget.textContent = this.active ? "Cancelar comparação" : "Comparar deputados"
  }

  syncDisabled() {
    const full = this.selected.length >= this.limitValue
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.disabled = full && !checkbox.checked
    })
  }

  load() {
    return this.read(STORAGE_KEY) || []
  }

  save() {
    this.write(STORAGE_KEY, this.selected)
  }

  read(key) {
    try {
      return JSON.parse(sessionStorage.getItem(key))
    } catch {
      return null
    }
  }

  write(key, value) {
    try {
      sessionStorage.setItem(key, JSON.stringify(value))
    } catch {
      // Sem storage disponível: modo e seleção valem só nesta página
    }
  }
}
