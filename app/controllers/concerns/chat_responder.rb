# Resposta comum aos dois pontos de entrada da conversa com a Harpia:
# o chat principal (chats#show) e o chat widget (presente em todas as páginas).
#
# Esta resposta imediata mostra a pergunta e o aviso "Estamos de olho...";
# a resposta da IA chega depois pelo WebSocket (ChatResponseJob).
#
# Os dois enviam o formulário dentro de um Turbo Frame próprio, e o Turbo
# informa qual é no cabeçalho "Turbo-Frame". Assim cada interface recebe
# somente as atualizações dos seus elementos:
# - widget            → mensagens e formulário do widget + lista de "Meus Chats"
# - chat principal    → mensagens, formulário e título da conversa
# - demais requisições (botão "Novo Chat", "Perguntar à Harpia", sem JS)
#   → redireciona para a página da conversa
module ChatResponder
  extend ActiveSupport::Concern

  WIDGET_FRAME = "chat_widget_messages".freeze
  CONVERSATION_FRAME = "chat_conversation".freeze

  AI_ERROR_MESSAGE = "Não foi possível gerar a resposta. Tente novamente.".freeze
  INVALID_MESSAGE = "Não foi possível enviar a mensagem.".freeze
  BUSY_MESSAGE = "Aguarde a Harpia terminar a resposta anterior.".freeze

  private

  # error_message: mensagem amigável exibida dentro da conversa quando
  # a pergunta não pode ser salva
  def respond_with_conversation(error_message: nil)
    case turbo_frame_request_id
    when WIDGET_FRAME then render turbo_stream: widget_streams(error_message)
    when CONVERSATION_FRAME then render turbo_stream: conversation_streams(error_message)
    else
      flash[:chat_error] = error_message if error_message
      redirect_to @chat
    end
  end

  def widget_streams(error_message)
    [
      turbo_stream.update(
        WIDGET_FRAME,
        partial: "chats/widget_messages",
        locals: { chat: @chat, error_message: error_message }
      ),

      # Se o usuário estiver na página "Meus Chats", a conversa
      # aparece na lista sem precisar atualizar o navegador.
      turbo_stream.update(
        "chats_list",
        partial: "chats/chats_list",
        locals: { chats: policy_scope(Chat) }
      )
    ]
  end

  def conversation_streams(error_message)
    [
      turbo_stream.update(
        CONVERSATION_FRAME,
        partial: "chats/conversation",
        locals: { chat: @chat, error_message: error_message }
      ),

      # O título é gerado depois da primeira pergunta dentro do escopo.
      turbo_stream.update(helpers.dom_id(@chat, :title), @chat.title.presence || Chat::DEFAULT_TITLE)
    ]
  end
end
