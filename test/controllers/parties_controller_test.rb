require "test_helper"

class PartiesControllerTest < ActionDispatch::IntegrationTest
  test "mostra a coesão e as votações divididas do partido" do
    get party_path(parties(:mdb))
    assert_response :success
    assert_select "div.display-6", text: "67%"
    assert_select "li", text: /Votação do requerimento B/
    assert_select "li", text: /Votação do requerimento A/, count: 0 # unânime
  end

  test "avisa quando não há dados de coesão" do
    get party_path(parties(:pt))
    assert_response :success
    assert_select "p", text: /pequena demais/
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
