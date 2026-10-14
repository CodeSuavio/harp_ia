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

  # Trecho da mensagem em volta do termo buscado, com o termo destacado.
  # Como a busca ignora acentos, o termo é localizado no texto sem acentos e
  # destacado como está escrito na mensagem ("votacao" destaca "votação").
  def chat_search_excerpt(content, query)
    text = strip_tags(content).squish
    term = written_term(text, query.to_s.strip) || query
    highlight(excerpt(text, term, radius: 60) || truncate(text, length: 120), term)
  end

  private

  def written_term(text, query)
    plain = I18n.transliterate(text).downcase
    # A posição só vale se tirar os acentos não mudou o tamanho do texto
    return unless plain.length == text.length

    plain_query = I18n.transliterate(query).downcase
    start = plain.index(plain_query)
    text[start, plain_query.length] if start
  end
end
