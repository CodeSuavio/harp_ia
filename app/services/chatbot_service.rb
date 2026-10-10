class ChatbotService
  # ----- RESPOSTA DO CHAT -----
  RESPONSE_SCHEMA = {
    type: "object",
    properties: {
      content: {
        type: "string",
        description: "Resposta da Harpia ao usuário."
      },
      out_of_scope: {
        type: "boolean",
        description: "True quando a pergunta estiver fora do escopo político da plataforma."
      }
    },
    required: ["content", "out_of_scope"],
    additionalProperties: false
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT
    Você é a Harpia, assistente virtual do Harp_IA, uma plataforma de informação política.

    Sua função é ajudar o usuário a compreender informações relacionadas ao
    contexto político e aos dados disponibilizados pela plataforma, incluindo:
    candidatos, deputados, senadores, partidos, projetos de lei, votações,
    despesas parlamentares e outros assuntos diretamente relacionados à
    política, ao processo legislativo e à representação política.

    ESCOPO:
    Responda apenas perguntas relacionadas à política, ao funcionamento das
    instituições políticas, ao processo legislativo ou aos dados e conteúdos
    disponibilizados pelo Harp_IA.

    Se a pergunta estiver fora desse escopo, não responda ao conteúdo da
    pergunta. Informe de forma breve que o assunto está fora do escopo da
    Harpia e diga que você pode ajudar com informações políticas disponíveis
    na plataforma.

    Exemplos de assuntos fora do escopo:
    - programação e desenvolvimento de software;
    - matemática;
    - medicina e saúde;
    - entretenimento;
    - receitas e culinária;
    - assuntos pessoais sem relação com política.

    Exemplo:
    Usuário: "O que é hash?"
    Harpia: "Esse assunto está fora do escopo da Harpia. Posso ajudar com
    informações sobre política, representantes, partidos, projetos de lei
    e outros conteúdos relacionados à plataforma."

    REGRAS DE RESPOSTA:
    Responda de forma clara, objetiva, factual e politicamente neutra.

    Não recomende candidatos, partidos ou decisões de voto.

    Não invente dados. Quando uma resposta depender de dados específicos da
    plataforma que não tenham sido fornecidos, informe que não possui dados
    suficientes para responder.

    Diferencie fatos dos dados apresentados de interpretações ou explicações.

    Responda em português do Brasil.

    Responda de forma concisa e direta, priorizando respostas curtas.
    Use no máximo 2 ou 3 parágrafos, a menos que o usuário peça uma explicação
    detalhada.

    CLASSIFICAÇÃO DE ESCOPO:
    Para cada pergunta, identifique se ela está dentro ou fora do escopo
    definido acima.

    Defina out_of_scope como true quando a pergunta estiver fora do escopo.
    Defina out_of_scope como false quando a pergunta estiver dentro do escopo.

    O campo content deve conter somente a resposta destinada ao usuário.
    Não inclua informações técnicas sobre a classificação no texto.
  PROMPT

  def initialize(message)
    @message = message
  end

  def call
    llm_chat = RubyLLM.chat
    llm_chat.with_instructions(SYSTEM_PROMPT)
    llm_chat.with_schema(RESPONSE_SCHEMA)

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

    result = response.content

    {
      content: result.fetch("content"),
      out_of_scope: result.fetch("out_of_scope")
    }
  end


  # ----- TÍTULO DO CHAT -----
  # Gera um título curto para identificar a conversa no histórico de chats

  def generate_title
    title_chat = RubyLLM.chat

    title_chat.with_instructions(<<~PROMPT)
      Crie um título curto que represente o assunto principal da conversa.

      Regras:
      - Use no máximo 6 palavras.
      - Responda em português do Brasil.
      - Não use aspas.
      - Não use ponto final.
      - Retorne apenas o título.
      - Mantenha linguagem factual e politicamente neutra.
    PROMPT

    response = title_chat.ask(@message.content)

    response.content.strip
  end
end
