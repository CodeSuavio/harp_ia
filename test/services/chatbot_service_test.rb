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

  test "as ferramentas, instanciadas com o registro de ações, mantêm a descrição e o nome do RubyLLM" do
    actions = HarpiaActions.new

    ChatbotService::TOOLS.each do |tool_class|
      tool = tool_class.new(actions)

      assert_kind_of String, tool.description, tool_class
      assert_predicate tool.description, :present?, tool_class
      assert_same actions, tool.actions
    end
  end
end
