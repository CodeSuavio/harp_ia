require "test_helper"

class ExpenseAlertRankingToolTest < ActiveSupport::TestCase
  setup do
    # Mesmo cenário da página de alertas (ExpenseAlertsControllerTest):
    # Ana (SP): 1 alta · Bruno (SP): 2 médias · Davi: 1 alta, valor maior · Carla: 1 baixa em 2024
    alert(:ana, :high, 1_000, ids: [expenses(:ana_fuel).id])
    alert(:bruno, :medium, 50_000, ids: [expenses(:bruno_fuel).id])
    alert(:bruno, :medium, 50_000, ids: [expenses(:bruno_fuel).id])
    alert(:davi, :high, 9_000)
    alert(:carla, :low, 100, year: 2024)
    @tool = ExpenseAlertRankingTool.new
  end

  test "responde se houve alerta de gravidade máxima num estado e ano" do
    result = @tool.call("severity" => "high", "state" => "sp", "year" => 2025)

    assert_equal 1, result[:deputados_com_alertas]
    assert_equal [["Ana Souza", { "alta" => 1 }]], (result[:ranking].map { |row| [row[:nome], row[:por_gravidade]] })
    assert_equal "gravidade alta, em SP, em 2025", result[:filtros]
    assert_nil result[:recorte]
    assert_equal ["Ver notas com alerta de Ana Souza"], (result[:acoes].map { |action| action[:rotulo] })
    assert_equal "/deputies/#{deputies(:ana).id}?alerts=1&tab=expenses&year=2025", @tool.actions.all.first.value
    assert_match "não são prova de irregularidade", result[:observacao]
  end

  test "mesma ordem e números da página de alertas, com recorte e continuação" do
    result = @tool.call("limit" => 1)

    assert_equal [["Davi Rocha", 5, 1]], (result[:ranking].map { |row| [row[:nome], row[:pontuacao], row[:alertas]] })
    assert_equal({ exibindo: 1, de: 3 }, result[:recorte])
    assert_equal 4, result[:total_de_alertas]
    assert_equal ["Ver lista completa", "Ver notas com alerta de Davi Rocha"],
                 (result[:acoes].map { |action| action[:rotulo] })
    assert_equal "/alertas?year=2025", @tool.actions.all.first.value
  end

  test "ordena pela parte do gasto em notas com alerta" do
    result = @tool.call("order" => "share")

    assert_equal ["Bruno Lima", "Ana Souza", "Davi Rocha"], result[:ranking].pluck(:nome)
    assert_in_delta 100.0, result[:ranking].first[:percentual_do_gasto_do_ano]
  end

  test "sem alertas no recorte, oferece a mesma consulta com todas as gravidades" do
    result = @tool.call("severity" => "medium", "state" => "RJ", "year" => 2024)

    assert_equal 0, result[:deputados_com_alertas]
    assert_empty result[:ranking]
    assert_equal ["Quais deputados têm alertas de gastos, todas as gravidades, em RJ, em 2024?"],
                 @tool.actions.all.map(&:value)
  end

  test "ano sem alertas calculados não é tratado como ano sem alertas" do
    ExpenseAlert.where(year: 2025).delete_all

    result = @tool.call("year" => 2025)

    assert_equal false, result[:alertas_calculados]
    assert_match "ainda não foram calculados", result[:observacao]
    assert_nil result[:ranking]
  end

  test "informa partido inexistente" do
    assert @tool.call("party" => "XYZ")[:erro]
  end

  test "a Harpia tem acesso aos alertas de gastos" do
    assert_includes ChatbotService::TOOLS, ExpenseAlertRankingTool
    assert_includes ChatbotService::SYSTEM_PROMPT, "expense_alert_ranking"
  end

  private

  def alert(deputy, severity, value, year: 2025, ids: [])
    ExpenseAlert.create!(deputy: deputies(deputy), year: year, kind: "atypical_note", severity: severity,
                         value: value, expense_ids: ids)
  end
end
