class ChatbotService
  SYSTEM_PROMPT = <<~PROMPT
    Você é o asssitente virtual do Harp_IA, uma plataforma de informação política.

    Sua função é ajudar o usuário a compreender informações sobre candidatos,
    deputados, partidos, projetos de lei, votações, despesas parlamentares e
    outros dados disponibilizados pela plataforma.

    Responda de forma clara, objetiva factual e politicamente neutra.

    Não recomende candidatos, partidos ou decisões de voto.
    Não invente dados. Quando uma resposta depender de dados específicos da
    plataforma que não tenham sido fornecidos, informe que não possui dados
    suficientes para responder.

    Diferencie fatos dos dados apresentados de interpretações ou explicações.
    Responda em português do Brasil.

    Responda de forma concisa e direta, priorizando respostas curtas.
    Use no máximo 2 ou 3 parágrafos, a menos que o usuário peça uma explicação
    detalhada.
  PROMPT

  def initialize(message)
    @message = message
  end

  def call
    llm_chat = RubyLLM.chat
    llm_chat.with_instructions(SYSTEM_PROMPT)

    # Busque as mensagens desse chat, exclua a mensagem
    # atual e coloque as mensagens em ordem de criação
    previous_messages = @message.chat.messages
      .where.not(id: @message.id)
      .order(:created_at)

    # Adiciona cada mensagem anterior ao contexto da LLM,
    # preservando quem enviou a mensagem e seu conteúdo
    previous_messages.each do |message|
      llm_chat.add_message(
        role: message.role.to_sym,
        content: message.content
      )
    end

    response = llm_chat.ask(@message.content)

    response.content
  end
end
