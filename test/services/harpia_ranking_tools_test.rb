require "test_helper"

class HarpiaRankingToolsTest < ActiveSupport::TestCase
  # ----- PARTIDOS -----

  test "ordena os partidos pelo número de deputados" do
    result = PartyRankingTool.new.call("criterion" => "seats")

    assert_equal(%w[MDB PT], result[:ranking].map { |row| row[:sigla] })
    assert_equal([3, 1], result[:ranking].map { |row| row[:valor] })
    assert_equal 4, result[:total_de_cadeiras]
    assert_equal "deputados", result[:unidade]
    assert result[:como_e_calculado]
    # Lista inteira: sem recorte e sem continuação
    assert_nil result[:recorte]
    assert_nil result[:acoes]
  end

  test "ranking de partidos cortado avisa o recorte e oferece ver mais e a lista completa" do
    tool = PartyRankingTool.new
    result = tool.call("criterion" => "seats", "limit" => 1)

    assert_equal({ exibindo: 1, de: 2 }, result[:recorte])
    assert_equal ["Ver mais", "Ver lista completa"], (result[:acoes].map { |action| action[:rotulo] })
    more, page = result[:acoes].map { |action| tool.actions.find(action[:id]) }
    assert_equal "Mostre as posições 2 a 2: partidos por cadeiras, do maior para o menor", more.value
    assert_equal "/parties/compare?dir=desc&sort=seats#indicadores", page.value
    assert(more.required && page.required)
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

  test "ordena os deputados pelo gasto" do
    result = DeputyRankingTool.new.call("criterion" => "expenses_total")

    assert_equal(["Bruno Lima", "Ana Souza"], result[:ranking].map { |row| row[:nome] })
    assert_equal([3000, 1000], result[:ranking].map { |row| row[:valor] })
    assert_equal 2025, result[:ano_dos_gastos]
    assert_equal "R$", result[:unidade]
    assert_equal 2, result[:deputados_sem_dados]
    assert_nil result[:recorte]
  end

  test "ranking de deputados cortado continua pela Harpia e pela listagem com os mesmos filtros" do
    tool = DeputyRankingTool.new
    result = tool.call("criterion" => "expenses_total", "state" => "sp", "order" => "asc", "limit" => 1)

    assert_equal({ exibindo: 1, de: 2 }, result[:recorte])
    more, page = result[:acoes].map { |action| tool.actions.find(action[:id]) }
    assert_equal "Mostre as posições 2 a 2: deputados por gasto total no ano, do menor para o maior, em SP, " \
                 "gastos de 2025", more.value
    assert_equal "/deputies?dir=asc&sort=expenses_total&state=SP", page.value
  end

  test "ver mais vai até o limite máximo da ferramenta; depois, só a lista completa" do
    tool = DeputyRankingTool.new
    continuation = ->(shown) { tool.send(:continuation, shown: shown, total: 30, max: 20, description: "x", page: "/deputies") }

    assert_equal ["Ver mais", "Ver lista completa"], (continuation.call(18).map { |action| action[:rotulo] })
    assert_equal "Mostre as posições 19 a 20: x", tool.actions.all.first.value
    assert_equal ["Ver lista completa"], (continuation.call(20).map { |action| action[:rotulo] })
    assert_nil continuation.call(30)
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

  test "ranking de projetos de um tema conta autoria e coautoria, sem repetir o projeto" do
    # Ana é autora principal e também está entre os autores: conta uma vez
    BillAuthor.create!(bill: bills(:ana_bill), deputy: deputies(:ana))
    BillAuthor.create!(bill: bills(:ana_bill), deputy: deputies(:bruno))
    health = Bill.create!(bill_type: "PL", number: 9, bill_number: "PL 9/2025", year: 2025, deputy: deputies(:davi))
    BillTheme.create!(bill: health, theme: themes(:saude))

    tool = DeputyRankingTool.new
    result = tool.call("criterion" => "bills", "theme" => "transparencia", "limit" => 2)

    assert_equal(["Ana Souza", "Bruno Lima"], result[:ranking].map { |row| row[:nome] })
    assert_equal([1, 1], result[:ranking].map { |row| row[:valor] })
    assert_equal({ tema: "Transparência e administração pública" }, result[:filtros])
    assert_match "classificados no tema Transparência", result[:como_e_calculado]
    # Quem não tem projeto no tema entra com zero
    assert_equal 0, result[:deputados_sem_dados]
    assert_equal({ exibindo: 2, de: 4 }, result[:recorte])

    # A listagem de deputados não filtra por tema: sem "Ver lista completa"
    actions = result[:acoes].map { |action| tool.actions.find(action[:id]) }
    assert_equal ["Ver mais", "Ver projetos de Ana Souza sobre Transparência e administração pública"],
                 actions.map(&:label)
    assert_equal "Mostre as posições 3 a 4: deputados por projetos de lei sobre Transparência e administração " \
                 "pública, do maior para o menor", actions.first.value
    assert_equal "/deputies/#{deputies(:ana).id}?tab=bills&theme=transparency", actions.last.value
  end

  test "tema só vale para o ranking de projetos" do
    assert_match "só vale para o indicador bills",
                 DeputyRankingTool.new.call("criterion" => "expenses", "theme" => "Saúde")[:erro]
    assert DeputyRankingTool.new.call("criterion" => "bills", "theme" => "astronomia")[:erro]
  end

  # ----- DEPUTADOS POR ESTADO -----

  test "conta os deputados de cada estado" do
    result = DeputyStateRankingTool.new.call({})

    assert_equal([["RJ", 2], ["SP", 2]], result[:ranking].map { |row| [row[:uf], row[:deputados]] })
    assert_equal 4, result[:total_de_deputados]
    assert_equal "deputados", result[:unidade]
    assert_nil result[:recorte]
  end

  test "deputados por estado cortado oferece só ver mais (não há página com este ranking)" do
    tool = DeputyStateRankingTool.new
    result = tool.call("limit" => 1)

    assert_equal [["RJ", 2]], (result[:ranking].map { |row| [row[:uf], row[:deputados]] })
    assert_equal({ exibindo: 1, de: 2 }, result[:recorte])
    assert_equal ["Mostre as posições 2 a 2: número de deputados por estado, do maior para o menor"],
                 tool.actions.all.map(&:value)
  end

  test "traz o deputado no topo do indicador em cada estado" do
    result = DeputyStateRankingTool.new.call("criterion" => "expenses_total")

    assert_equal([["SP", "Bruno Lima", 3000]], result[:estados].map { |row| [row[:uf], row[:nome], row[:valor]] })
    assert_equal 2025, result[:ano_dos_gastos]
    assert_nil result[:acoes]
  end

  test "recusa critério desconhecido no ranking por estado" do
    assert DeputyStateRankingTool.new.call("criterion" => "idade")[:erro]
  end

  # ----- CANDIDATOS -----

  test "conta os candidatos por estado, do maior para o menor" do
    add_candidates

    result = CandidateRankingTool.new.call("group_by" => "state")

    assert_equal([["SP", 3], ["RJ", 1]], result[:ranking].map { |row| [row[:grupo], row[:candidatos]] })
    assert_equal([75.0, 25.0], result[:ranking].map { |row| row[:percentual] })
    assert_equal 4, result[:total_de_candidatos]
    assert_equal "candidatos", result[:unidade]
    assert_nil result[:recorte]
    assert_equal ["Ver os candidatos (em SP)", "Ver os candidatos (em RJ)"], (result[:acoes].map { |action| action[:rotulo] })
    assert result[:como_e_calculado]
  end

  test "contagem de candidatos leva à página de candidatos de cada grupo e dos filtros" do
    add_candidates
    tool = CandidateRankingTool.new
    result = tool.call("group_by" => "gender", "state" => "sp")

    assert_nil result[:recorte]
    assert_equal ["Ver os candidatos (em SP, gênero feminino)", "Ver os candidatos (em SP, gênero masculino)",
                  "Ver os candidatos (em SP)"], (result[:acoes].map { |action| action[:rotulo] })
    assert_equal ["/candidates?gender=FEMININO&state=SP", "/candidates?gender=MASCULINO&state=SP",
                  "/candidates?state=SP"], tool.actions.all.map(&:value)
  end

  test "contagem de candidatos cortada oferece ver mais; grupo sem filtro na página não tem link" do
    add_candidates
    tool = CandidateRankingTool.new

    result = tool.call("group_by" => "party", "limit" => 1)
    assert_equal({ exibindo: 1, de: 2 }, result[:recorte])
    assert_equal ["Ver mais", "Ver os candidatos (do MDB)"], (result[:acoes].map { |action| action[:rotulo] })
    assert_equal "/candidates?party=#{parties(:mdb).id}", tool.actions.find(result[:acoes].last[:id]).value

    result = CandidateRankingTool.new.call("group_by" => "race_color")
    assert_nil result[:acoes]
  end

  test "filtra os candidatos por estado, partido e gênero" do
    add_candidates

    result = CandidateRankingTool.new.call("group_by" => "gender", "state" => "sp", "party" => "pt")

    assert_equal([["FEMININO", 1]], result[:ranking].map { |row| [row[:grupo], row[:candidatos]] })
    assert_equal({ uf: "SP", partido: "PT" }, result[:filtros])
  end

  test "inverte a ordem, agrupa por partido e informa os candidatos sem o dado" do
    add_candidates

    result = CandidateRankingTool.new.call("group_by" => "gender", "order" => "asc")

    assert_equal(%w[FEMININO MASCULINO], result[:ranking].map { |row| row[:grupo] })
    assert_equal 1, result[:candidatos_sem_informacao]
    assert_equal(%w[MDB PT], CandidateRankingTool.new.call("group_by" => "party")[:ranking].map { |row| row[:grupo] })
  end

  test "informa partido inexistente e agrupamento inválido no ranking de candidatos" do
    assert CandidateRankingTool.new.call("group_by" => "state", "party" => "XYZ")[:erro]
    assert CandidateRankingTool.new.call("group_by" => "idade")[:erro]
  end

  test "a Harpia tem acesso ao ranking de candidatos" do
    assert_includes ChatbotService::TOOLS, CandidateRankingTool
    assert_includes ChatbotService::TOOLS, DeputyStateRankingTool
    assert_includes ChatbotService::SYSTEM_PROMPT, "candidate_ranking"
  end

  private

  # Além da Ana (SP, MDB, sem gênero na fixture): 2 em SP e 1 no RJ
  def add_candidates
    rows = [["SP", :mdb, "MASCULINO"], ["SP", :pt, "FEMININO"], ["RJ", :mdb, "MASCULINO"]]
    rows.each_with_index do |(uf, party, gender), i|
      Candidate.create!(name: "Candidato #{i}", ballot_name: "Candidato #{i}", number: 2000 + i,
                        party: parties(party), state_label: uf, gender: gender)
    end
  end
end
