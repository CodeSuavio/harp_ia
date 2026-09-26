import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["member", "photo", "name", "bio"]

  connect() {
    this.memberTargets.forEach((member) => {
      const username = member.dataset.username
      if (username) {
        this.fetchGitHubData(username, member)
      }
    })
  }

  async fetchGitHubData(username, member) {
    try {
      const response = await fetch(`https://api.github.com/users/${username}`)

      if (response.ok) {
        const data = await response.json()

        const photoEl = member.querySelector('[data-github-team-target="photo"]')
        const nameEl = member.querySelector('[data-github-team-target="name"]')
        const bioEl = member.querySelector('[data-github-team-target="bio"]')

        // 1. Foto do GitHub
        if (photoEl && data.avatar_url) {
          photoEl.src = data.avatar_url
          photoEl.classList.remove('d-none')

          const placeholder = member.querySelector('.inspiration-photo-placeholder')
          if (placeholder) placeholder.classList.add('d-none')
        }

        // 2. Nome: Se o GitHub tiver nome preenchido, usa ele. Senão, mantém o fallback do HTML.
        if (nameEl && data.name && data.name.trim() !== "") {
          nameEl.textContent = data.name
        }

        // 3. Bio: Se o GitHub tiver bio, usa ela. Senão, mantém a frase personalizada do HTML.
        // if (bioEl && data.bio && data.bio.trim() !== "") {
        //   bioEl.textContent = data.bio
        // }
      }
    } catch (error) {
      console.error(`Erro ao buscar dados do GitHub para ${username}`, error)
    }
  }
}
