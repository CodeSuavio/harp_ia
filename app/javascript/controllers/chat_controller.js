import { Controller } from "@hotwired/stimulus"

// Comportamento compartilhado pelas duas formas de conversar com a Harpia:
// o chat principal (chats#show) e o chat widget. Cada interface fornece
// apenas a própria aparência, pelos <template> abaixo.
//
// Connects to data-controller="chat"
export default class extends Controller {
  static targets = [
    "messages",            // área com scroll onde ficam as mensagens
    "userMessage",         // perguntas do usuário, usadas como âncora do scroll
    "placeholder",         // estado vazio, removido na primeira pergunta
    "input",               // campo da pergunta
    "userMessageTemplate", // aparência da pergunta exibida antes da resposta
    "loadingTemplate",     // feedback enquanto a IA processa
    "errorTemplate"        // aviso amigável quando a requisição falha
  ]

  send(event) {
    const form = event.currentTarget
    const input = form.elements["message[content]"]
    const question = input?.value.trim()

    // Impede perguntas vazias e novos envios enquanto a Harpia
    // ainda está respondendo, evitando mensagens duplicadas.
    if (this.busy || !question) {
      event.preventDefault()
      return
    }

    this.busy = true
    this.pendingQuestion = question

    // Informa a página atual, para a Harpia entender perguntas como
    // "o que significa esse alerta?" sem o usuário dizer de onde fala.
    const pagePath = form.elements["message[page_path]"]
    if (pagePath) pagePath.value = window.location.pathname + window.location.search

    this.showPending(question)
  }

  lock(event) {
    // O Turbo já capturou os dados do formulário neste momento,
    // portanto o campo pode ser limpo sem alterar a mensagem enviada ao Rails.
    const input = event.currentTarget.elements["message[content]"]
    if (input) input.value = ""

    this.toggleForm(event.currentTarget, true)
  }

  unlock(event) {
    this.busy = false
    this.toggleForm(event.currentTarget, false)

    // Se a requisição falhou antes de o Rails responder (rede, erro 500),
    // a conversa não é atualizada: avisa o usuário e devolve a pergunta ao campo.
    if (!event.detail.success) {
      this.showFailure()

      const input = event.currentTarget.elements["message[content]"]
      if (input && !input.value) input.value = this.pendingQuestion || ""
    }

    // A resposta substitui o formulário logo depois deste evento;
    // o foco vai para o campo novo assim que ele aparecer.
    this.shouldFocus = true
    this.focusInput()
  }

  // Enter envia; Shift+Enter quebra a linha (campos de várias linhas).
  submitOnEnter(event) {
    if (event.shiftKey || event.isComposing) return

    event.preventDefault()
    event.currentTarget.form.requestSubmit()
  }

  // Sem esse tratamento, uma resposta inesperada do servidor faria o Turbo
  // trocar a conversa por "Content missing".
  keepConversation(event) {
    event.preventDefault()
  }

  inputTargetConnected() {
    if (this.shouldFocus) {
      this.shouldFocus = false
      this.focusInput()
    }
  }

  messagesTargetConnected() {
    // Sempre que o Turbo renderiza novamente a área de mensagens,
    // posiciona a conversa na interação mais recente.
    this.scrollToLatestInteraction()
  }

  scrollToLatestInteraction() {
    // Posiciona a última pergunta do usuário no início da área visível,
    // permitindo visualizar a pergunta e o começo da resposta juntos.
    // Rola somente a área de mensagens, sem mover o restante da página.
    requestAnimationFrame(() => {
      if (!this.hasMessagesTarget || !this.hasUserMessageTarget) return

      const container = this.messagesTarget
      const lastUserMessage = this.userMessageTargets[this.userMessageTargets.length - 1]
      const offset = lastUserMessage.getBoundingClientRect().top - container.getBoundingClientRect().top
      const padding = parseFloat(getComputedStyle(container).paddingTop) || 0

      container.scrollTo({ top: container.scrollTop + offset - padding, behavior: "smooth" })
    })
  }

  // ----- AUXILIARES -----

  showPending(question) {
    if (!this.hasMessagesTarget) return

    this.placeholderTargets.forEach((placeholder) => placeholder.remove())

    // Exibe imediatamente a pergunta enviada e o feedback de carregamento,
    // sem precisar aguardar a resposta da IA.
    this.messagesTarget.append(this.build(this.userMessageTemplateTarget, question))
    this.messagesTarget.append(this.build(this.loadingTemplateTarget))

    this.scrollToLatestInteraction()
  }

  showFailure() {
    if (!this.hasMessagesTarget) return

    this.messagesTarget.querySelectorAll("[data-chat-loading]").forEach((loading) => loading.remove())
    this.messagesTarget.append(this.build(this.errorTemplateTarget))
  }

  // Copia o conteúdo de um <template>, preenchendo o texto em [data-chat-text].
  build(template, text) {
    const node = template.content.firstElementChild.cloneNode(true)

    if (text !== undefined) {
      const slot = node.querySelector("[data-chat-text]") || node
      slot.textContent = text
    }

    return node
  }

  toggleForm(form, disabled) {
    form.querySelectorAll('[name="message[content]"], [type="submit"]').forEach((field) => {
      field.disabled = disabled
    })
  }

  focusInput() {
    if (this.hasInputTarget && !this.inputTarget.disabled) this.inputTarget.focus()
  }
}
