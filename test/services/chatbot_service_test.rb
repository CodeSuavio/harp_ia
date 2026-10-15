require "test_helper"

class ChatbotServiceTest < ActiveSupport::TestCase
  test "limpa as opções de escolha" do
    replies = ChatbotService.new(Message.new).quick_replies([" A ", "", "A", "B", "C", "D", "E"])

    assert_equal %w[A B C D], replies
    assert_equal [], ChatbotService.new(Message.new).quick_replies(nil)
  end

  test "a Harpia escolhe os próximos passos entre os oferecidos pelas ferramentas" do
    assert_includes ChatbotService::RESPONSE_SCHEMA[:required], "acoes"
    assert_includes ChatbotService::SYSTEM_PROMPT, "Só existem os passos devolvidos pelas ferramentas"
    assert_includes ChatbotService::SYSTEM_PROMPT, "Nunca apresente uma parte como a\nlista completa"
    assert_includes ChatbotService::SYSTEM_PROMPT, "Cada botão deve levar direto a uma resposta com dados"
  end

  test "guarda as ações escolhidas, sem a página atual e sem ações nas perguntas fora do escopo" do
    message = Message.new(page_path: "/parties/compare?sort=seats")
    service = ChatbotService.new(message)
    actions = HarpiaActions.new
    page = actions.link("Ver lista completa", "/parties/compare?sort=seats", required: true)
    party = actions.question("Sobre o PT", "Mostre os dados do partido PT")
    service.instance_variable_set(:@actions, actions)

    picked = service.actions("acoes" => [page[:id], party[:id]], "quick_replies" => ["Por gastos"])

    assert_equal ["Sobre o PT", "Por gastos"], picked.pluck("label")
  end

  test "na página com gráficos, a Harpia recebe as seções; no histórico, só a página" do
    message = Message.new(page_path: "/parties/compare?sort=seats", page_context: "Comparação entre partidos",
                          content: "O que esse gráfico mostra?")
    service = ChatbotService.new(message)

    assert_includes service.page_instructions, "PÁGINA ATUAL DO USUÁRIO: Comparação entre partidos"
    assert_includes service.page_instructions, PartyComparison::SECTIONS["affinity"][:title]
    assert_equal "[Pergunta feita na página: Comparação entre partidos]\nO que esse gráfico mostra?",
                 service.history_content(message)
  end

  test "páginas anteriores com gráficos chegam como referência, da mais recente para a mais antiga" do
    chat = users(:renata).chats.create!
    ask(chat, "Explique o mapa de posicionamento", "/parties/compare")
    ask(chat, "E aqui?", "/deputies/compare?sort=expenses")
    ask(chat, "Quem é esta deputada?", "/deputies/#{deputies(:ana).id}")
    instructions = ChatbotService.new(ask(chat, "Explique o mapa de posicionamento", "/chats/#{chat.id}"))
                                 .page_instructions

    # Sem página atual: nenhuma página anterior vira "atual"
    assert_not_includes instructions, "PÁGINA ATUAL"
    panorama, parties = instructions.split("PÁGINA DE UMA PERGUNTA ANTERIOR").drop(1)
    assert_includes panorama, "Panorama de comparação entre os deputados"
    assert_includes panorama, "o usuário não está nela agora"
    assert_not_includes panorama, "SEÇÕES DA PÁGINA"
    assert_includes panorama, DeputyPanorama::SECTIONS["positioning"][:chart]
    assert_not_includes panorama, DeputyPanorama::SECTIONS["positioning"][:reading] # só o resumo
    assert_includes parties, "Comparação entre partidos"
    assert_includes instructions, "Mapa de posicionamento (panorama de deputados e comparação de partidos)"
  end

  test "título repetido é avisado com a página anterior e as páginas com ferramenta de dados" do
    chat = users(:renata).chats.create!
    ask(chat, "Quais blocos aparecem aqui?", "/deputies/compare")
    instructions = ChatbotService.new(ask(chat, "Explique o mapa", "/chats/#{chat.id}")).page_instructions

    assert_includes instructions, "Mapa de posicionamento (panorama de deputados e comparação de partidos)"
    assert_not_includes instructions, "Quem vota com quem ("
  end

  test "numa página com gráficos, a página atual decide: sem aviso de títulos repetidos" do
    chat = users(:renata).chats.create!
    ask(chat, "Quais blocos aparecem aqui?", "/deputies/compare")
    instructions = ChatbotService.new(ask(chat, "Explique o mapa", "/parties/compare")).page_instructions

    assert_includes instructions, "PÁGINA ATUAL DO USUÁRIO: Comparação entre partidos"
    assert_includes instructions, "PÁGINA DE UMA PERGUNTA ANTERIOR"
    assert_not_includes instructions, "MESMO NOME"
  end

  test "a página atual não se repete como página anterior" do
    chat = users(:renata).chats.create!
    ask(chat, "O que esse gráfico mostra?", "/deputies/compare")
    instructions = ChatbotService.new(ask(chat, "E o mapa?", "/deputies/compare")).page_instructions

    assert_includes instructions, "PÁGINA ATUAL DO USUÁRIO: Panorama de comparação entre os deputados"
    assert_not_includes instructions, "PERGUNTA ANTERIOR"
  end

  test "conversa sem páginas com gráficos não recebe guia" do
    chat = users(:renata).chats.create!
    ask(chat, "Quem é esta deputada?", "/deputies/#{deputies(:ana).id}")

    assert_nil ChatbotService.new(ask(chat, "E os gastos?", "/chats/#{chat.id}")).page_instructions
  end

  test "gráfico citado pelo nome usa os dados mesmo sem página; sem referência clara, pergunta qual" do
    prompt = ChatbotService::SYSTEM_PROMPT.squish

    assert_includes prompt, "consulte a ferramenta dele, com ou sem página informada"
    assert_includes prompt, "Quando houver mais de uma interpretação conhecida"
    assert_includes prompt, "não escolha uma: pergunte qual"
    assert_includes prompt, "nunca invente nomes de gráficos"
    assert_includes prompt, "o usuário não está nessas páginas agora"
    assert_includes prompt, "a plataforma não tem esse gráfico"
    assert_includes prompt, "só quando a página atual ou a pergunta tratarem do mesmo assunto dela"
    assert_includes prompt, "Perguntas sobre os gráficos e as páginas da plataforma estão sempre dentro do escopo"
    assert_includes ChatbotService::TOOLS, PartyComparisonTool
  end

  test "as ferramentas, instanciadas com o registro de ações, mantêm a descrição e o nome do RubyLLM" do
    actions = HarpiaActions.new

    ChatbotService::TOOLS.each do |tool_class|
      tool = tool_class.new(actions)

      assert_kind_of String, tool.description, tool_class
      assert_predicate tool.description, :present?, tool_class
      assert_same actions, tool.actions
    end
  end

  private

  # Pergunta salva como MessageProcessorService salva (página só quando reconhecida)
  def ask(chat, content, page_path)
    context = PageContextService.new(page_path).call
    chat.messages.create!(role: "user", content: content, page_context: context, page_path: (page_path if context))
  end
end
