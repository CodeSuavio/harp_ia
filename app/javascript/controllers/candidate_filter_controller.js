import { Controller } from "@hotwired/stimulus"

// Filters the candidate directory cards by name, party and state without a page reload.
export default class extends Controller {
  static targets = ["search", "state", "card", "emptyState"]

  filter() {
    const query = this.normalize(this.searchTarget.value)
    const state = this.stateTarget.value
    let visibleCount = 0

    this.cardTargets.forEach((card) => {
      // Usa || "" para evitar erros caso o HTML não tenha o data-attribute
      const filterName = this.normalize(card.dataset.filterName || "")
      const partyLabels = this.normalize(card.dataset.filterPartyLabel || "").split(/\s+/)
      const partyName = this.normalize(card.dataset.filterPartyName || "")
      const filterState = card.dataset.filterState || ""

      // Sigla precisa ser exata (atual ou antiga) para "PT" não trazer PTB, PSTU etc.
      const matchesQuery = query === "" ||
        filterName.includes(query) ||
        partyLabels.includes(query) ||
        partyName.includes(query)
      const matchesState = state === "" || filterState === state

      const isVisible = matchesQuery && matchesState

      card.classList.toggle("d-none", !isVisible)
      if (isVisible) visibleCount += 1
    })

    // Mostra o empty state apenas se count for 0
    this.emptyStateTarget.classList.toggle("d-none", visibleCount > 0)
  }

  // Minúsculas e sem acentos, para "democracia crista" achar "Democracia Cristã"
  normalize(text) {
    return text.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  }
}
