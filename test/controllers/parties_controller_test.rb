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

  test "ordena partidos por coesão, sem dados por último" do
    get parties_path(sort: "cohesion")
    assert_response :success
    assert_equal %w[MDB PT], css_select(".list-group-item strong").map(&:text)
  end
end
