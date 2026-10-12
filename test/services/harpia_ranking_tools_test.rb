require "test_helper"

class HarpiaRankingToolsTest < ActiveSupport::TestCase
  # ----- PARTIDOS -----

  test "ordena os partidos pelo número de deputados" do
    result = PartyRankingTool.new.call("criterion" => "seats")

    assert_equal(%w[MDB PT], result[:ranking].map { |row| row[:sigla] })
    assert_equal([3, 1], result[:ranking].map { |row| row[:valor] })
    assert_equal 4, result[:total_de_cadeiras]
    assert_equal "deputados", result[:unidade]
    assert_equal "/parties/compare?dir=desc&sort=seats#indicadores", result[:pagina]
    assert result[:como_e_calculado]
  end

  test "inverte a ordem e limita o ranking de partidos" do
    result = PartyRankingTool.new.call("criterion" => "seats", "order" => "asc", "limit" => 1)

    assert_equal(["PT"], result[:ranking].map { |row| row[:sigla] })
    assert_equal 1, result[:ranking].first[:posicao]
  end

  test "separa os partidos sem dados do indicador" do
    result = PartyRankingTool.new.call("criterion" => "expenses")

    assert_equal(["MDB"], result[:ranking].map { |row| row[:sigla] })
    assert_equal ["PT"], result[:partidos_sem_dados]
    assert_equal 2025, result[:ano_dos_gastos]
  end

  test "recusa critério desconhecido no ranking de partidos" do
    assert PartyRankingTool.new.call("criterion" => "idade")[:erro]
  end

  # ----- DEPUTADOS -----

  test "ordena os deputados pelo gasto e indica a página da listagem" do
    result = DeputyRankingTool.new.call("criterion" => "expenses_total")

    assert_equal(["Bruno Lima", "Ana Souza"], result[:ranking].map { |row| row[:nome] })
    assert_equal([3000, 1000], result[:ranking].map { |row| row[:valor] })
    assert_equal 2025, result[:ano_dos_gastos]
    assert_equal "R$", result[:unidade]
    assert_equal 2, result[:deputados_sem_dados]
    assert_equal "/deputies?sort=expenses_total", result[:pagina]
  end

  test "usa o ano pedido no ranking de gastos" do
    result = DeputyRankingTool.new.call("criterion" => "expenses_total", "year" => 2024)

    assert_equal 2024, result[:ano_dos_gastos]
    assert_equal([["Ana Souza", 500]], result[:ranking].map { |row| [row[:nome], row[:valor]] })
  end

  test "filtra os deputados por estado e partido" do
    result = DeputyRankingTool.new.call("criterion" => "against_party", "state" => "rj", "party" => "mdb")

    assert_equal(["Carla Dias"], result[:ranking].map { |row| row[:nome] })
    assert_equal({ uf: "RJ", partido: "MDB" }, result[:filtros])
    assert_includes result[:pagina], "state=RJ"
  end

  test "mostra o número de votações junto da participação" do
    row = DeputyRankingTool.new.call("criterion" => "participation", "order" => "asc")[:ranking].first

    assert row.key?(:votou)
    assert row.key?(:votacoes_no_periodo)
  end

  test "informa partido inexistente e critério inválido no ranking de deputados" do
    assert DeputyRankingTool.new.call("criterion" => "bills", "party" => "XYZ")[:erro]
    assert DeputyRankingTool.new.call("criterion" => "idade")[:erro]
  end
end
