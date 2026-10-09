import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat-widget"
export default class extends Controller {
  static targets = [
    "button",
    "window",
    "messages",
    "userMessage",
  ]

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

  showLoading(event) {
    // Localiza o campo de texto do formulário que acabou de ser enviado.
    const input = event.currentTarget.querySelector('input[name="message[content]"]')

    // Impede o envio caso o campo não seja encontrado
    // ou a pergunta esteja vazia.
    if (!input || !input.value.trim()) {
      event.preventDefault()
      return
    }
    
    // Guarda a pergunta antes de limpar o campo.
    const question = input.value.trim()

    // Localiza a área onde as mensagens da conversa são exibidas.
    const messages = this.windowTarget.querySelector(".chat-widget-messages")

    if (messages) {
    // Exibe imediatamente a pergunta enviada pelo usuário.
    const userMessage = document.createElement("div")
    userMessage.classList.add("chat-widget-user-message")
    userMessage.dataset.chatWidgetTarget = "userMessage"
    userMessage.textContent = question

    messages.appendChild(userMessage)
    // Exibe o feedback enquanto a IA processa a resposta.
    const loading = document.createElement("div")
    loading.classList.add("chat-widget-loading")
    loading.textContent = "Estamos de olho..."

    messages.appendChild(loading)
    // Posiciona imediatamente a nova pergunta no início da área
    // visível, sem precisar aguardar a resposta da IA.
    this.scrollToLatestInteraction()
    }
  }

  clearInput(event) {
    // O Turbo já capturou os dados do formulário neste momento,
   // portanto o campo pode ser limpo sem alterar a mensagem enviada ao Rails.
    const input = event.currentTarget.querySelector('input[name="message[content]"]')

    if (input) {
    input.value = ""
    }
  }

    disableForm(event) {
      // Localiza o formulário que acabou de ser enviado.
      const form = event.currentTarget

      // Localiza o campo de texto e o botão de envio.
      const input = form.querySelector('input[name="message[content]"]')
      const button = form.querySelector('button[type="submit"]')

      // Impede novos envios enquanto a Harpia processa a resposta.
      if (input) input.disabled = true
      if (button) button.disabled = true
  }

    enableForm(event) {
      // Localiza o formulário após o Turbo finalizar a requisição.
      const form = event.currentTarget

      // Localiza o campo de texto e o botão de envio.
      const input = form.querySelector('input[name="message[content]"]')
      const button = form.querySelector('button[type="submit"]')

      // Libera novamente o formulário para uma nova pergunta.
      if (input) input.disabled = false
      if (button) button.disabled = false

      // Devolve o foco ao campo de texto.
      if (input) input.focus()
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
