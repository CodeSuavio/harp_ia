import { Controller } from "@hotwired/stimulus"

// Tooltip do Bootstrap nos ícones "como calculamos" (sem Bootstrap, fica o `title` nativo)
export default class extends Controller {
  connect() {
    const Tooltip = window.bootstrap?.Tooltip
    if (Tooltip) this.tooltip = Tooltip.getOrCreateInstance(this.element, { trigger: "hover focus" })
  }

  disconnect() {
    this.tooltip?.dispose()
  }
}
