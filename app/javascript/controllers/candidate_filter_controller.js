import { Controller } from "@hotwired/stimulus"

// Filters the candidate directory cards by name and state without a page reload.
export default class extends Controller {
  static targets = ["search", "state", "card", "emptyState"]

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    const state = this.stateTarget.value
    let visibleCount = 0

    this.cardTargets.forEach((card) => {
      const matchesQuery = card.dataset.filterName.includes(query)
      const matchesState = state === "" || card.dataset.filterState === state
      const isVisible = matchesQuery && matchesState

      card.classList.toggle("d-none", !isVisible)
      if (isVisible) visibleCount += 1
    })

    this.emptyStateTarget.classList.toggle("d-none", visibleCount > 0)
  }
}
