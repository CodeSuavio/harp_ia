require "test_helper"

class CampaignFinancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ana (SP, MDB): R$ 100 mil e 20 mil votos = R$ 5/voto, eleita
    # Bruno (SP, PT): R$ 50 mil e 1 mil votos = R$ 50/voto, suplente
    # Carla (RJ, PT): R$ 10 mil e nenhum voto, não eleita
    finance(candidates(:ana_2026), expenses: 100_000, votes: 20_000, result: "ELEITO POR QP",
            revenues: 120_000, public_funds: 90_000, own_funds: 12_000)
    finance(candidate("Bruno Lima", :pt, "SP"), expenses: 50_000, votes: 1_000, result: "SUPLENTE")
    finance(candidate("Carla Dias", :pt, "RJ"), expenses: 10_000, votes: 0, result: "NÃO ELEITO")
  end

  test "é pública, mostra gasto, votos e custo por voto, do maior gasto para o menor" do
    get campaign_finances_path
    assert_response :success
    assert_equal ["Ana Souza", "Bruno Lima", "Carla Dias"], card_names
    assert_select ".campaign-card a.stretched-link[href=?]", candidate_path(candidates(:ana_2026))
    assert_select ".campaign-card .campaign-cost", text: "R$ 5,00"
    assert_select ".campaign-card .badge", text: /Eleito/
    # Ana: 20 mil de 21 mil votos nominais de SP; 75% da receita veio de fundos públicos; 10% próprios
    assert_match "95,24%", response.body
    assert_match "75,0%", response.body
    assert_match "10,0%", response.body
  end

  test "indicadores do recorte: totais, custo médio e mediana de eleitos x demais" do
    get campaign_finances_path
    assert_match "R$ 160.000", response.body # gasto total
    assert_match "21.000", response.body      # votos nominais
    assert_match "R$ 7,62", response.body     # 160 mil ÷ 21 mil
    assert_match "R$ 50,00", response.body    # mediana dos não eleitos (Carla sem voto fica de fora)
  end

  test "ordena pelo custo por voto, só com quem gastou e teve voto" do
    get campaign_finances_path(sort: "cost_desc")
    assert_equal ["Bruno Lima", "Ana Souza"], card_names

    get campaign_finances_path(sort: "cost_asc")
    assert_equal ["Ana Souza", "Bruno Lima"], card_names
  end

  test "filtra por estado, partido, resultado e busca" do
    get campaign_finances_path(state: "RJ")
    assert_equal ["Carla Dias"], card_names

    get campaign_finances_path(party: parties(:pt).id)
    assert_equal ["Bruno Lima", "Carla Dias"], card_names

    get campaign_finances_path(result: "elected")
    assert_equal ["Ana Souza"], card_names

    get campaign_finances_path(q: "bruno")
    assert_equal ["Bruno Lima"], card_names
  end

  test "faixas de gasto mostram quantos se elegeram" do
    get campaign_finances_path
    assert_select ".campaign-quartiles li", 3
    assert_select ".campaign-quartiles li", text: /100,0%\s+eleitos\s+\(1 de 1\)/
  end

  private

  def candidate(name, party, state)
    Candidate.create!(name: name, ballot_name: name, number: rand(1000..9999), party: parties(party), state_label: state)
  end

  def finance(candidate, **attributes)
    CampaignFinance.create!(candidate: candidate, **attributes)
  end

  def card_names
    css_select(".campaign-card h2 a").map { |link| link.text.strip }
  end
end
