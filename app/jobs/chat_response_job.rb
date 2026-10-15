# Gera, em segundo plano, a resposta da Harpia a uma pergunta do usuário e a
# envia pelo WebSocket para as telas abertas da conversa (chat principal e
# widget), que assinam o canal com turbo_stream_from. O texto aparece aos
# poucos, enquanto a IA escreve, e a resposta completa substitui tudo no final.
#
# Não há nova tentativa automática: repetir a chamada poderia duplicar a
# resposta e o custo da IA. Em caso de falha, a pergunta fica como "failed"
# e o usuário pode perguntar novamente.
class ChatResponseJob < ApplicationJob
  # Fila exclusiva, com worker próprio: rotinas de manutenção nunca atrasam a resposta
  queue_as :harpia

  # A conversa foi excluída antes de o job rodar
  discard_on ActiveJob::DeserializationError

  # Intervalo mínimo, em segundos, entre os envios do texto parcial: a tela
  # acompanha a IA sem ser redesenhada a cada pedaço recebido. Igual ao
  # polling do Solid Cable em produção (config/cable.yml), que não entrega
  # mensagens em intervalos menores.
  STREAM_INTERVAL = 0.1

  def perform(question)
    return unless question.pending?

    @chat = question.chat
    chatbot = ChatbotService.new(question)

    result = answer(question, chatbot)
    broadcast_conversation

    # O título é gerado depois que a resposta já está na tela, para não atrasá-la,
    # e somente quando a pergunta está dentro do escopo da Harpia
    generate_title(chatbot) if result && @chat.title.blank? && !result[:out_of_scope]
  end

  private

  def answer(question, chatbot)
    result = chatbot.call { |text| broadcast_partial(text) }

    # Salva a resposta da IA na mesma conversa
    # e registra se a pergunta estava fora do escopo e os próximos passos em botões
    Message.transaction do
      @chat.messages.create!(role: "assistant", **result.slice(:content, :out_of_scope, :actions).compact)
      question.answered!
    end

    result
  rescue StandardError => e
    Rails.logger.error("[ChatResponseJob] Erro ao gerar resposta da IA: #{e.class} - #{e.message}")
    question.failed!
    nil
  end

  def generate_title(chatbot)
    @chat.update!(title: chatbot.generate_title)
    broadcast_title
  rescue StandardError => e
    # Sem título a conversa continua funcionando, com o título padrão
    Rails.logger.error("[ChatResponseJob] Erro ao gerar título: #{e.class} - #{e.message}")
  end

  # ----- WEBSOCKET -----
  # Os alvos usam o id da conversa (dom_id), para que a resposta de uma
  # conversa nunca apareça na tela de outra.

  # Texto parcial da resposta, enquanto a IA escreve. Cada envio leva o texto
  # inteiro recebido até ali e substitui o "Estamos de olho..." (e depois o
  # envio anterior), sem duplicar nada. Um envio perdido, por exemplo antes
  # de a tela se inscrever no canal, é coberto pelo seguinte, e a resposta
  # completa (broadcast_conversation) substitui o texto parcial no final.
  def broadcast_partial(text)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return if @partial_sent_at && now - @partial_sent_at < STREAM_INTERVAL

    @partial_sent_at = now

    { stream_conversation: false, stream_widget: true }.each do |target, widget|
      @chat.broadcast_replace_to @chat,
                                 target: ActionView::RecordIdentifier.dom_id(@chat, target),
                                 partial: "chats/streamed_answer",
                                 locals: { chat: @chat, text: text, widget: widget }
    end
  end

  def broadcast_conversation
    @chat.broadcast_replace_to @chat,
                               target: ActionView::RecordIdentifier.dom_id(@chat, :conversation),
                               partial: "chats/conversation",
                               locals: { chat: @chat }

    @chat.broadcast_replace_to @chat,
                               target: ActionView::RecordIdentifier.dom_id(@chat, :widget),
                               partial: "chats/widget_messages",
                               locals: { chat: @chat }

    broadcast_chats_list
  end

  def broadcast_title
    @chat.broadcast_update_to @chat,
                              target: ActionView::RecordIdentifier.dom_id(@chat, :title),
                              html: @chat.title

    broadcast_chats_list
  end

  # Se o usuário estiver na página "Meus Chats", a conversa aparece
  # (e depois com o título) sem precisar atualizar o navegador.
  def broadcast_chats_list
    @chat.broadcast_update_to @chat,
                              target: "chats_list",
                              partial: "chats/chats_list",
                              locals: { chats: @chat.user.chats.in_history }
  end
end
