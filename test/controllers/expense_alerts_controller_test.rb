require "test_helper"

class ExpenseAlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ana: 1 alta (5 pts) · Bruno: 2 médias (4 pts) · Davi: 1 alta (5 pts), valor maior que o de Ana
    # Notas com alerta: Ana R$ 300 de R$ 1.000 (30%) · Bruno a mesma nota nos 2 alertas, R$ 3.000 de 3.000 (100%)
    alert(:ana, :high, 1_000, ids: [expenses(:ana_fuel).id])
    alert(:bruno, :medium, 50_000, ids: [expenses(:bruno_fuel).id])
    alert(:bruno, :medium, 50_000, ids: [expenses(:bruno_fuel).id])
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

  test "ordena pela parte do gasto em notas com alerta, contando cada nota uma vez" do
    get expense_alerts_path(order: "share")
    assert_equal ["Bruno Lima", "Ana Souza", "Davi Rocha"], card_names
    assert_match "100,0% do gasto", response.body
    assert_match "30,0% do gasto", response.body
  end

  test "mostra quando os alertas foram calculados e avisa quando o ano ainda não foi" do
    get expense_alerts_path
    assert_match "Alertas calculados em #{Date.current.strftime('%d/%m/%Y')}", response.body

    ExpenseAlert.where(year: 2025).delete_all
    get expense_alerts_path(year: 2025)
    assert_match "Os alertas de 2025 ainda não foram calculados", response.body
  end

  test "pagina os deputados" do
    party = parties(:pt)
    25.times do |i|
      deputy = Deputy.create!(name: "Deputado #{i}", cpf: (50_000_000_000 + i).to_s, json_id: 9_000 + i,
                              state_label: "BA", party: party)
      ExpenseAlert.create!(deputy: deputy, year: 2025, kind: "month_peak", severity: :low, value: i)
    end

    get expense_alerts_path(state: "BA")
    assert_equal ExpenseAlertsController::PER_PAGE, card_names.size
    assert_select ".pagination a[href=?]", expense_alerts_path(year: 2025, state: "BA", page: 2)

    get expense_alerts_path(state: "BA", page: 2)
    assert_equal ["Deputado 0"], card_names # menor valor sinalizado, último no desempate
  end

  private

  def alert(deputy, severity, value, year: 2025, ids: [])
    ExpenseAlert.create!(deputy: deputies(deputy), year: year, kind: "atypical_note", severity: severity,
                         value: value, expense_ids: ids)
  end

  def card_names
    css_select(".card h2 a").map { |link| link.text.strip }
  end
end
