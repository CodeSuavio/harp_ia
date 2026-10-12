module ChatsHelper
  # Ações do chat_controller ligadas aos formulários do chat principal e do
  # widget, para que os dois tenham sempre o mesmo comportamento.
  CHAT_FORM_ACTIONS = "submit->chat#send " \
                      "turbo:submit-start->chat#lock " \
                      "turbo:submit-end->chat#unlock".freeze

  # Ações do elemento que contém a conversa.
  CHAT_ACTIONS = "turbo:frame-missing->chat#keepConversation".freeze

  def chat_form_data(frame)
    { turbo_frame: frame, action: CHAT_FORM_ACTIONS }
  end

  # Marca a área de mensagens enquanto a Harpia responde. O chat_controller
  # usa essas informações para pedir o estado atual da conversa caso a
  # resposta não chegue pelo WebSocket.
  def chat_pending_data(chat, awaiting)
    return unless awaiting

    tag.attributes(data: { chat_pending: true, chat_refresh_url: chat_path(chat) })
  end
end
