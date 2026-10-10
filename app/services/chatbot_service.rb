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
    plataforma, consulte-os com as ferramentas disponíveis antes de responder.
    Se as ferramentas não retornarem a informação, informe que não possui
    dados suficientes para responder.

    Diferencie fatos dos dados apresentados de interpretações ou explicações.

    Responda em português do Brasil.

    Responda de forma concisa e direta, priorizando respostas curtas.
    Use no máximo 2 ou 3 parágrafos, a menos que o usuário peça uma explicação
    detalhada.

    DADOS DA PLATAFORMA:
    Você tem ferramentas que consultam o banco de dados do Harp_IA:
    - search_platform: encontra o id de deputados, partidos, projetos de lei,
      votações e candidatos pelo nome ou termo;
    - deputy_details, party_details, bill_details, poll_details e
      candidate_details: trazem os dados e as análises exibidas nas páginas.

    Use-as sempre que o usuário perguntar sobre um registro específico ou
    pedir para entender uma análise, um indicador ou um alerta. Ao explicar
    um indicador, use o critério retornado pela ferramenta (por exemplo, o
    campo "criterio" dos alertas de gastos) e os números do próprio registro.

    Alertas de gastos indicam valores fora do padrão segundo critérios
    estatísticos; deixe claro que não são prova de irregularidade.

    Quando for informada a página atual do usuário, considere que
    termos como "este deputado", "esse alerta", "essa votação" ou "este
    gráfico" se referem ao registro dessa página. Perguntas anteriores da
    conversa podem indicar a página em que foram feitas; use isso para saber
    de quem ou do que o usuário falava, mesmo que ele tenha mudado de página.

    CLASSIFICAÇÃO DE ESCOPO:
    Para cada pergunta, identifique se ela está dentro ou fora do escopo
    definido acima.

    Defina out_of_scope como true quando a pergunta estiver fora do escopo.
    Defina out_of_scope como false quando a pergunta estiver dentro do escopo.

    O campo content deve conter somente a resposta destinada ao usuário.
    Não inclua informações técnicas sobre a classificação no texto.
  PROMPT

  # Ferramentas somente leitura que a IA pode usar para consultar o banco
  TOOLS = [
    SearchPlatformTool,
    DeputyDetailsTool,
    PartyDetailsTool,
    BillDetailsTool,
    PollDetailsTool,
    CandidateDetailsTool
  ].freeze

  def initialize(message)
    @message = message
  end

  def call
    llm_chat = RubyLLM.chat
    llm_chat.with_instructions(SYSTEM_PROMPT)
    llm_chat.with_instructions(page_instructions, append: true) if @message.page_context
    llm_chat.with_tools(*TOOLS)
    llm_chat.with_schema(RESPONSE_SCHEMA)

    # Busque as mensagens desse chat, exclua a mensagem
    # atual e coloque as mensagens em ordem de criação
    previous_messages = @message.chat.messages
      .where.not(id: @message.id)
      .order(:created_at)

    # Adiciona cada mensagem anterior ao contexto da LLM,
    # preservando quem enviou a mensagem, seu conteúdo e
    # a página em que a pergunta foi feita
    previous_messages.each do |message|
      llm_chat.add_message(
        role: message.role.to_sym,
        content: history_content(message)
      )
    end

    response = llm_chat.ask(@message.content)

    result = response.content

    {
      content: result.fetch("content"),
      out_of_scope: result.fetch("out_of_scope")
    }
  end


  # ----- PÁGINA ATUAL -----
  # Informado a cada pergunta, porque o usuário pode trocar de página
  # no meio da conversa

  def page_instructions
    "PÁGINA ATUAL DO USUÁRIO: #{@message.page_context}"
  end

  def history_content(message)
    return message.content if message.page_context.blank?

    "[Pergunta feita na página: #{message.page_context}]\n#{message.content}"
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
