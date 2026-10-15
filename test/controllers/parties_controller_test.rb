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

  test "comparação mostra destaques, blocos e a tabela de indicadores" do
    get compare_parties_path
    assert_response :success
    assert_select "h1", text: /Comparar partidos/
    assert_select ".party-insight", minimum: 1
    assert_select ".party-compare-table tbody tr", 2
    assert_select ".party-compare-table a[href=?]", party_path(parties(:mdb))
    assert_select ".bloc-majority", text: "257"
    # Com as 3 votações das fixtures, ninguém chega ao mínimo de governismo: os dois
    # partidos vão para a linha "Sem dados", fora das colunas dos blocos
    assert_select ".bloc-legend-item", 0
    assert_select "p", text: /Sem dados\s+\(4 cadeiras\)/
  end

  test "comparação ordena pela coluna pedida e ignora coluna desconhecida" do
    get compare_parties_path(sort: "seats", dir: "asc")
    assert_select ".party-compare-table tbody tr:first-child th a", text: "PT"
    assert_select "th[aria-sort=ascending]", text: /Cadeiras/

    get compare_parties_path(sort: "xyz", dir: "sideways")
    assert_response :success
    assert_select ".party-compare-table tbody tr:first-child th a", text: "MDB"
  end

  test "lista de partidos tem o hero das páginas e o mapa de bancadas da home" do
    get parties_path
    assert_response :success
    assert_select ".panel-hero h1", text: /Partidos/
    assert_select ".camera-viewfinder", 0
    assert_select "#partidos[data-controller~='party-map'] .uf-tile", 27
    assert_select "a[href=?]", compare_parties_path

    get parties_path(uf: "sp")
    assert_select "#partidos[data-party-map-selected-value=?]", "SP"
  end

  test "comparação lado a lado dos partidos escolhidos" do
    get compare_parties_path(ids: [parties(:pt).id, parties(:mdb).id])
    assert_response :success
    assert_select ".compare-table thead th[scope=col]", 2
    assert_equal %w[PT MDB], css_select(".compare-table thead th[scope=col] span.fw-bold").map(&:text)
    assert_select ".compare-table tbody th", text: /Gasto médio mensal/
    assert_select ".compare-table td.compare-best", minimum: 1
    assert_match(/(PT|MDB)<\/strong> e <strong class="text-navy">(PT|MDB)/, response.body)
    assert_select ".party-compare-table", 0
  end

  test "comparação lado a lado pede ao menos dois partidos e ignora ids desconhecidos" do
    get compare_parties_path(ids: [parties(:mdb).id, 0])
    assert_response :success
    assert_match "Selecione de 2", response.body
    assert_select ".compare-table", 0
  end
end
