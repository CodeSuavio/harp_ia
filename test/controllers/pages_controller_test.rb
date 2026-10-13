require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home mostra o hero e o mapa de partidos com os 27 estados e o JSON traz as bancadas nacional e por estado" do
    get root_path
    assert_response :success
    assert_select ".camera-viewfinder .capital-dot", 27
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
    get root_path(uf: "rj")
    assert_select "[data-party-map-selected-value=RJ]"

    get root_path(uf: "XX")
    assert_select "[data-party-map-selected-value='']"
  end

  test "home leva à comparação" do
    get root_path
    assert_select "a[href=?]", compare_parties_path
  end

  test "home tem o modo de escolher partidos para comparar" do
    get root_path
    assert_select "[data-controller~=compare-selection][data-compare-selection-url-value=?]", compare_parties_path
    assert_select "button[data-action='compare-selection#toggleMode']", text: /Escolher partidos/
    assert_select "template input[data-compare-selection-target=checkbox][data-field=compare]"
  end
end
