class MessageProcessorService
  # page_path: caminho da página em que o usuário fez a pergunta
  # (ex.: "/deputies/12?tab=expenses"), enviado pelo widget
  def initialize(chat, content, page_path: nil)
    @chat = chat
    @content = content
    @page_path = page_path
  end

  def call
    # Salva a mensagem enviada pelo usuário junto com a página em que
    # ela foi feita, para a IA saber a que "este deputado" se referia
    # mesmo depois que o usuário mudar de página
    user_message = @chat.messages.create!(
      content: @content,
      role: "user",
      status: :pending,
      page_context: PageContextService.new(@page_path).call
    )

    # A resposta da IA pode levar vários segundos (consultas às ferramentas,
    # título da conversa). Ela é gerada em segundo plano e chega à tela pelo
    # WebSocket, sem prender a requisição do usuário.
    ChatResponseJob.perform_later(user_message)

    # Retorna a mensagem criada pelo usuário
    user_message
  end
end
