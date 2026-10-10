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
      result = chatbot.call
    rescue StandardError => e
      Rails.logger.error(
        "[MessageProcessorService] Erro ao gerar resposta da IA: #{e.class} - #{e.message}"
      )

      raise AIError, "Não foi possível gerar a resposta da IA."
    end

    # Salva a resposta da IA na mesma conversa
    # e registra se a pergunta estava fora do escopo da Harpia
    @chat.messages.create!(
      content: result[:content],
      role: "assistant",
      out_of_scope: result[:out_of_scope]
    )

    # Gera um título somente quando a conversa ainda não possui título
    # e a pergunta está dentro do escopo da Harpia.
    if @chat.title.blank? && !result[:out_of_scope]
      @chat.update!(title: chatbot.generate_title)
    end

    # Retorna a mensagem criada pelo usuário
    user_message
  end
end
