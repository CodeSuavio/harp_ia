import { Controller } from "@hotwired/stimulus"

// Controlador para carregar fotos e biografias dinamicamente do GitHub
export default class extends Controller {
  // Define os alvos (targets) que vamos manipular no HTML
  static targets = ["member", "photo", "name", "bio"]

  connect() {
    // Para cada cartão de membro da equipe, dispara a busca de dados
    this.memberTargets.forEach((member) => {
      const username = member.dataset.username
      if (username) {
        this.fetchGitHubData(username, member)
      }
    })
  }

  async fetchGitHubData(username, member) {
    try {
      // Consome a API pública do GitHub para o usuário específico
      const response = await fetch(`https://api.github.com/users/${username}`)

      if (response.ok) {
        const data = await response.json()

        // Isola os alvos apenas dentro do cartão atual para não alterar os outros membros
        const photoEl = member.querySelector('[data-github-team-target="photo"]')
        const nameEl = member.querySelector('[data-github-team-target="name"]')
        const bioEl = member.querySelector('[data-github-team-target="bio"]')

        // Substitui o placeholder pela foto real do GitHub
        if (photoEl && data.avatar_url) {
          photoEl.src = data.avatar_url
          photoEl.classList.remove('d-none')

          const placeholder = member.querySelector('.inspiration-photo-placeholder')
          if (placeholder) placeholder.classList.add('d-none')
        }

        // Atualiza o nome do fundador com o nome do perfil
        if (nameEl && data.name) {
          nameEl.textContent = data.name
        }

        // Se o usuário tiver uma biografia cadastrada no GitHub, substitui o texto base
        if (bioEl && data.bio) {
          bioEl.textContent = data.bio
        }
      }
    } catch (error) {
      console.error(`Erro ao buscar dados do GitHub para ${username}`, error)
    }
  }
}
