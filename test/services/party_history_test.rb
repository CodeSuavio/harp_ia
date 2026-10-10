require "test_helper"

class PartyHistoryTest < ActiveSupport::TestCase
  PREDECESSORS = { "REPUBLICANOS" => %w[PRB], "PL" => %w[PR], "UNIÃO" => %w[PSL DEM] }.freeze

  def record(date, legislature, label, status = "Alteração de partido")
    { "dataHora" => "#{date}T00:00", "idLegislatura" => legislature, "siglaPartido" => label, "descricaoStatus" => status }
  end

  def entries(*records)
    PartyHistory.new(records, predecessors: PREDECESSORS).entries.map { |e| [e.started_on.to_s, e.party_label, e.kind] }
  end

  test "período de cada legislatura" do
    assert_equal Date.new(2023, 2, 1)...Date.new(2027, 2, 1), PartyHistory.legislature_period(57)
    assert_equal Date.new(2019, 2, 1), PartyHistory.legislature_period(56).begin
  end

  test "ordena por data e junta registros repetidos do mesmo partido" do
    result = entries(
      record("2023-02-01", 57, "MDB", "Nome no início da legislatura / Partido no início da legislatura"),
      record("2026-04-10", 57, "PT"),
      record("2023-02-01", 57, "MDB", "Entrada - Posse de Eleito Titular")
    )
    assert_equal [["2023-02-01", "MDB", "first"], ["2026-04-10", "PT", "switch"]], result
  end

  test "ignora o partido de início de legislatura com data fora da legislatura" do
    # A Câmara repete o partido atual, com a data de geração do histórico, em legislaturas antigas e na próxima
    result = entries(
      record("2023-02-01", 58, "PT", "Nome no início da legislatura / Partido no início da legislatura"),
      record("2023-02-01", 57, "MDB", "Nome no início da legislatura / Partido no início da legislatura"),
      record("2026-04-10", 57, "PT"),
      record("2011-02-01", 54, "PSB", "Entrada - Posse de Eleito Titular"),
      record("2023-02-01", 54, "PT", "Nome no início da legislatura / Partido no início da legislatura")
    )
    assert_equal [["2011-02-01", "PSB", "first"], ["2023-02-01", "MDB", "new_term"], ["2026-04-10", "PT", "switch"]], result
  end

  test "mudança de nome ou fusão não é troca, e a sigla antiga repetida depois é ignorada" do
    result = entries(
      record("2019-02-01", 56, "PRB", "Entrada - Posse de Eleito Titular"),
      record("2019-08-16", 56, "REPUBLICANOS"),
      record("2020-04-02", 56, "PRB"),
      record("2022-02-23", 56, "UNIÃO")
    )
    assert_equal [["2019-02-01", "PRB", "first"], ["2019-08-16", "REPUBLICANOS", "rename"], ["2022-02-23", "UNIÃO", "switch"]], result
  end

  test "sigla antiga e nova no mesmo dia viram um registro só, com a nova" do
    result = entries(record("2022-07-14", 56, "PR", "Entrada - Posse de Suplente"), record("2022-07-14", 56, "PL"))
    assert_equal [["2022-07-14", "PL", "first"]], result
  end

  test "ignora registros sem data ou sem sigla" do
    assert_empty entries(record("", 57, "PT"), record("2023-02-01", 57, ""))
  end

  test "lê nomes antigos e fusões dos partidos" do
    parties(:mdb).update!(former_labels: "PMDB")
    predecessors = PartyHistory.predecessors
    assert_includes predecessors["MDB"], "PMDB"
    assert_includes predecessors["UNIÃO"], "DEM" # Party::MERGERS
    assert_includes predecessors["DEM"], "PFL" # HISTORICAL_RENAMES
  end
end
