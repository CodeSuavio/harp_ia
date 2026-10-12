require "test_helper"

class ExpenseAlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ana: 1 alta (5 pts) · Bruno: 2 médias (4 pts) · Davi: 1 alta (5 pts), valor maior que o de Ana
    alert(:ana, :high, 1_000)
    alert(:bruno, :medium, 50_000)
    alert(:bruno, :medium, 50_000)
    alert(:davi, :high, 9_000)
    alert(:carla, :low, 100, year: 2024)
  end

  test "é pública e ordena pela pontuação, com desempate pelo valor sinalizado" do
    get expense_alerts_path
    assert_response :success
    assert_equal ["Davi Rocha", "Ana Souza", "Bruno Lima"], card_names
    assert_select "a[href=?]", deputy_path(deputies(:davi), tab: "expenses", year: 2025)
    assert_match "Alerta não é prova de irregularidade", response.body
  end

  test "filtra por UF, partido e gravidade mínima" do
    get expense_alerts_path(state: "SP")
    assert_equal ["Ana Souza", "Bruno Lima"], card_names

    get expense_alerts_path(party: parties(:pt).id)
    assert_equal ["Davi Rocha"], card_names

    get expense_alerts_path(severity: "high")
    assert_equal ["Davi Rocha", "Ana Souza"], card_names
  end

  test "filtra pelo ano" do
    get expense_alerts_path(year: 2024)
    assert_equal ["Carla Dias"], card_names
  end

  test "mostra badges por gravidade e o total gasto no ano" do
    get expense_alerts_path(state: "SP")
    assert_select ".badge.text-bg-danger", text: /Alta: 1/
    assert_select ".badge.text-bg-warning", text: /Média: 2/
    assert_match "R$ 3.000", response.body # total de Bruno em 2025
  end

  private

  def alert(deputy, severity, value, year: 2025)
    ExpenseAlert.create!(deputy: deputies(deputy), year: year, kind: "atypical_note", severity: severity, value: value)
  end

  def card_names
    css_select(".card h2 a").map { |link| link.text.strip }
  end
end
