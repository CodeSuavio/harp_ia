import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-widget"
export default class extends Controller {
  static targets = ["button", "window", "messages", "userMessage"]

  connect() {
    // Mantém o widget fechado quando a página é carregada.
    this.windowTarget.hidden = true
  }

  open() {
    // Esconde o botão flutuante e abre a janela do chatbot.
    this.buttonTarget.hidden = true
    this.windowTarget.hidden = false

    // Ao abrir uma conversa existente, posiciona a visualização
    // na pergunta mais recente do usuário.
    this.scrollToLatestInteraction()
  }

  close() {
    // Fecha a janela do chatbot e exibe novamente o botão flutuante.
    this.windowTarget.hidden = true
    this.buttonTarget.hidden = false
  }

  messagesTargetConnected() {
    // Sempre que o Turbo renderiza novamente a área de mensagens,
    // posiciona a conversa na interação mais recente.
    this.scrollToLatestInteraction()
  }

  scrollToLatestInteraction() {
    // Posiciona a última pergunta do usuário no início da área visível,
    // permitindo visualizar a pergunta e o começo da resposta juntos.
    requestAnimationFrame(() => {
      if (this.hasUserMessageTarget) {
        const lastUserMessage =
          this.userMessageTargets[this.userMessageTargets.length - 1]

        lastUserMessage.scrollIntoView({
          behavior: "smooth",
          block: "start"
        })
      }
    })
  }
}
