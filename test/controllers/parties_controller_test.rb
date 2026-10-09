require "test_helper"

class PartiesControllerTest < ActionDispatch::IntegrationTest
  test "visão geral mostra os indicadores, o mapa e a bancada" do
    get party_path(parties(:mdb))
    assert_response :success
    assert_select "h1", text: "MDB"
    assert_select ".party-bench-map a.uf-tile", 27
    assert_select ".party-bench-map a[href=?] .uf-seats", parties_path(uf: "SP"), text: "2"
    assert_select "a[href=?]", deputy_path(deputies(:ana))
  end

  test "mostra a coesão e as votações divididas do partido" do
    get party_path(parties(:mdb), tab: "votes")
    assert_response :success
    assert_select "div.display-6", text: "67%"
    assert_select "li", text: /Votação do requerimento B/
    assert_select "div.display-6", text: "50%" # seguiu a orientação em 1 de 2
  end

  test "avisa quando não há dados de coesão" do
    get party_path(parties(:pt), tab: "votes")
    assert_response :success
    assert_select "p", text: /pequena demais/
  end

  test "mostra a federação no cabeçalho" do
    get party_path(parties(:pt))
    assert_select ".badge", text: /Federação PT-PCdoB-PV/
  end

  test "abre as abas de gastos, projetos e candidatos" do
    %w[expenses bills candidates].each do |tab|
      [parties(:mdb), parties(:pt)].each do |party|
        get party_path(party, tab: tab)
        assert_response :success, "aba #{tab} de #{party.label}"
      end
    end

    get party_path(parties(:mdb), tab: "expenses")
    assert_select ".h4", text: /4\.000/

    get party_path(parties(:mdb), tab: "candidates")
    assert_select "a[href=?]", candidates_path(party: parties(:mdb).id)
  end

  test "aba desconhecida cai na visão geral" do
    get party_path(parties(:mdb), tab: "xyz")
    assert_response :success
    assert_select ".nav-link.active", text: "Visão geral"
  end

  test "mapa tem os 27 estados e o JSON traz as bancadas nacional e por estado" do
    get parties_path
    assert_response :success
    assert_select ".uf-tile[data-uf]", 27
    assert_select ".uf-tile[data-uf=SP] .uf-seats", text: "2"

    data = JSON.parse(css_select("[data-party-map-target=data]").first.text)
    mdb = parties(:mdb).id.to_s
    pt = parties(:pt).id.to_s
    assert_equal({ mdb => 3, pt => 1 }, data["national"])
    assert_equal({ mdb => 1, pt => 1 }, data.dig("states", "RJ", "seats"))
    assert_equal({}, data.dig("states", "AC", "seats"))
  end

  test "pré-seleciona o estado do ?uf= e ignora UF inválida" do
    get parties_path(uf: "rj")
    assert_select "[data-party-map-selected-value=RJ]"

    get parties_path(uf: "XX")
    assert_select "[data-party-map-selected-value='']"
  end
end
