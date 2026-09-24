import { Controller } from "@hotwired/stimulus"

// Filters the candidate directory cards by name and state without a page reload.
export default class extends Controller {
  static targets = ["search", "state", "card", "emptyState"]

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    const state = this.stateTarget.value
    let visibleCount = 0

    this.cardTargets.forEach((card) => {
      // Usa || "" para evitar erros caso o HTML não tenha o data-attribute
      const filterName = card.dataset.filterName || ""
      const filterState = card.dataset.filterState || ""

      // Transforma o filterName em minúsculas também por precaução
      const matchesQuery = filterName.toLowerCase().includes(query)
      const matchesState = state === "" || filterState === state

      const isVisible = matchesQuery && matchesState

      card.classList.toggle("d-none", !isVisible)
      if (isVisible) visibleCount += 1
    })

    // Mostra o empty state apenas se count for 0
    this.emptyStateTarget.classList.toggle("d-none", visibleCount > 0)
  }
}
