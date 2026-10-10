class MessageProcessorService
  class AIError < StandardError; end

  def initialize(chat, content)
    @chat = chat
    @content = content
  end

  def call
    # Salva a mensagem enviada pelo usuário
    user_message = @chat.messages.create!(
      content: @content,
      role: "user"
    )

    # Envia a mensagem para a IA
    chatbot = ChatbotService.new(user_message)
    begin
      assistant_response = chatbot.call
    rescue StandardError => e
      Rails.logger.error(
          "[MessageProcessorService] Erro ao gerar resposta da IA: #{e.class} - #{e.message}"
      )

      raise AIError, "Não foi possível gerar a resposta da IA."
    end

    # Salva a resposta da IA na mesma conversa
    @chat.messages.create!(
      content: assistant_response,
      role: "assistant"
    )

    # Gera um título somente quando a conversa ainda não possui um.
    # Na prática, isso acontece na primeira interação do chat.
    if @chat.title.blank?
      @chat.update!(title: chatbot.generate_title)
    end

    # Retorna a mensagem criada pelo usuário.
    # Isso permite que quem chamou o service utilize o resultado,
    # caso seja necessário posteriormente.
    user_message
  end
end
