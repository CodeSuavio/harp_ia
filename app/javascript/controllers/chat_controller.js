import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A resposta da Harpia chega pelo WebSocket. Se ela demorar mais do que isso
// (ex.: a conexão caiu), o controller pede ao servidor o estado da conversa.
const REFRESH_DELAY = 10000

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

    // A resposta substitui o formulário logo depois deste evento. Ele chega
    // bloqueado enquanto a Harpia responde; o foco vai para o campo assim
    // que a resposta chegar pelo WebSocket e o formulário for liberado.
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

  inputTargetConnected(input) {
    if (this.shouldFocus && !input.disabled) {
      this.shouldFocus = false
      input.focus()
    }
  }

  messagesTargetConnected(messages) {
    // A área de mensagens renderizada de novo começa no topo. Ela volta, sem
    // animação, à posição em que o usuário estava, para a tela não "pular".
    if (this.savedScroll !== undefined) {
      messages.scrollTop = this.savedScroll
      this.savedScroll = undefined
    }

    // Posiciona a conversa na interação mais recente. Se ela já está
    // visível (ex.: a resposta chegou abaixo da pergunta), nada se move.
    this.scrollToLatestInteraction()

    // Cada nova renderização (resposta pelo WebSocket ou pela consulta
    // abaixo) substitui a anterior; só a mais recente agenda a consulta.
    clearTimeout(this.refreshTimer)
    if ("chatPending" in messages.dataset) {
      this.refreshTimer = setTimeout(() => this.refresh(messages), REFRESH_DELAY)
    }
  }

  connect() {
    // O Turbo marca o canal da conversa (turbo_stream_from) com o atributo
    // "connected" quando a inscrição no WebSocket é confirmada, inclusive
    // depois de uma reconexão. A resposta pode ter sido transmitida antes
    // disso (ex.: primeira pergunta do widget), então a conversa é consultada.
    this.streamObserver = new MutationObserver((mutations) => {
      const connected = mutations.some(({ target }) => target.hasAttribute("connected"))
      const messages = this.hasMessagesTarget && this.messagesTarget

      if (connected && messages && "chatPending" in messages.dataset) this.refresh(messages)
    })

    this.streamObserver.observe(this.element, { subtree: true, attributeFilter: ["connected"] })

    // Guarda a posição da rolagem antes de cada atualização da conversa
    // (envio da pergunta, resposta pelo WebSocket ou consulta abaixo).
    this.saveScroll = () => {
      if (this.hasMessagesTarget) this.savedScroll = this.messagesTarget.scrollTop
    }
    document.addEventListener("turbo:before-stream-render", this.saveScroll)
  }

  disconnect() {
    clearTimeout(this.refreshTimer)
    this.streamObserver?.disconnect()
    document.removeEventListener("turbo:before-stream-render", this.saveScroll)
  }

  // Busca o estado atual da conversa (ChatsController#show em Turbo Stream),
  // para o caso de a resposta ter sido transmitida enquanto a tela não
  // estava conectada ao WebSocket. Se a Harpia ainda estiver respondendo,
  // o servidor responde 204 e outra consulta é agendada.
  async refresh(messages) {
    const frame = messages.closest("turbo-frame")
    if (!frame || !messages.isConnected) return

    clearTimeout(this.refreshTimer)

    try {
      const response = await fetch(messages.dataset.chatRefreshUrl, {
        headers: { Accept: "text/vnd.turbo-stream.html", "Turbo-Frame": frame.id }
      })
      if (response.status === 204) {
        this.refreshTimer = setTimeout(() => this.refresh(messages), REFRESH_DELAY)
      } else if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
      }
    } catch {
      // Sem conexão: tenta novamente mais tarde, se a tela ainda estiver aguardando.
      if (messages.isConnected) this.refreshTimer = setTimeout(() => this.refresh(messages), REFRESH_DELAY)
    }
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
