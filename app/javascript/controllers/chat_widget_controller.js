import { Controller } from "@hotwired/stimulus"

// Abre e fecha a janela do widget. A conversa em si (envio, carregamento,
// bloqueio de envios e scroll) fica no chat_controller, compartilhado com
// o chat principal.
//
// Connects to data-controller="chat-widget"
export default class extends Controller {
  static targets = ["button", "window"]

  // A janela começa fechada pelo atributo hidden do HTML. O estado não é
  // redefinido no connect porque o widget é permanente entre as páginas
  // (data-turbo-permanent) e reconecta a cada navegação.

  open() {
    // Esconde o botão flutuante e abre a janela do chatbot.
    this.buttonTarget.hidden = true
    this.windowTarget.hidden = false

    // Avisa o chat_controller para posicionar a conversa
    // na pergunta mais recente (evento "chat-widget:opened").
    this.dispatch("opened")
  }

  close() {
    // Fecha a janela do chatbot e exibe novamente o botão flutuante.
    this.windowTarget.hidden = true
    this.buttonTarget.hidden = false
  }
}
