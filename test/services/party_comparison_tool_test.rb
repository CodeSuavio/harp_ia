require "test_helper"

class PartyComparisonToolTest < ActiveSupport::TestCase
  setup do
    # As fixtures têm só 3 votações; o mínimo real (20) deixaria todos sem governismo
    @comparison = PartyComparison.new(min_government_polls: 1)
    @tool = tool_for(@comparison)
  end

  test "blocos com as mesmas cadeiras e partidos da página" do
    result = @tool.call("section" => "blocs")

    assert_equal "A Câmara em blocos", result[:secao]
    assert_equal PartyComparison::MAJORITY, result[:maioria_absoluta]
    assert_equal @comparison.total_seats, result[:total_de_cadeiras]
    assert_equal PartyComparison::SECTIONS["blocs"][:how], result[:como_e_calculado]

    center = result[:blocos].find { |bloc| bloc[:bloco] == "Centro" }
    assert_equal @comparison.blocs[:center][:seats], center[:cadeiras]
    assert_equal [{ sigla: "MDB", cadeiras: 3, governismo_pct: 50 }], center[:partidos]
    assert_nil result[:sem_dados]
  end

  test "partidos sem governismo aparecem como sem dados nos blocos" do
    result = tool_for(PartyComparison.new).call("section" => "blocs")

    assert_equal({ cadeiras: 4, partidos: %w[MDB PT] }, result[:sem_dados])
    assert(result[:blocos].all? { |bloc| bloc[:cadeiras].zero? })
  end

  test "mapa de posicionamento com eixos, bolhas sobrepostas e partidos fora do mapa" do
    mdb, pt = @comparison.rows
    positioned = [row(mdb, governism: 94, cohesion: 95), row(pt, governism: 95, cohesion: 95)]
    @comparison.define_singleton_method(:positioned) { positioned }
    rows = positioned + [row(pt, governism: nil, cohesion: nil, label: "NOVO")]
    @comparison.define_singleton_method(:rows) { rows }

    result = @tool.call("section" => "positioning")

    assert_includes result[:o_que_mostra], PartyComparison::SECTIONS["positioning"][:reading]
    assert_equal({ sigla: "MDB", nome: mdb.party.name, cadeiras: 3, bloco: "Governista", governismo_pct: 94,
                   votacoes_com_orientacao_do_governo: 40, coesao_pct: 95 }, result[:partidos].first)
    # Bolhas quase no mesmo ponto: a menor fica sobre a maior, como na lista abaixo do mapa
    assert_equal ["PT dentro do MDB"], result[:bolhas_sobrepostas]
    assert_equal ["NOVO"], result[:fora_do_mapa]
  end

  test "sem partidos suficientes o mapa não é exibido" do
    assert_match(/não é exibido/, tool_for(PartyComparison.new).call("section" => "positioning")[:aviso])
  end

  test "afinidade em pares, do que mais vota junto ao que menos vota junto" do
    mdb, pt = @comparison.rows
    psol = row(pt, governism: 90, cohesion: 90, label: "PSOL", id: -1)
    cells = { [mdb.party.id, pt.party.id] => { same: 12, common: 30, pct: 40 },
              [pt.party.id, psol.party.id] => { same: 27, common: 30, pct: 90 } }
    cells.merge!(cells.transform_keys(&:reverse)) # a página consulta nos dois sentidos
    @comparison.define_singleton_method(:affinity) { { parties: [psol, pt, mdb], cells: cells, left_out: [] } }

    result = @tool.call("section" => "affinity")

    assert_equal %w[PSOL PT MDB], result[:ordem_na_matriz]
    assert_equal [{ partidos: "PSOL e PT", mesmo_lado_pct: 90, votacoes_em_comum: 30 },
                  { partidos: "PT e MDB", mesmo_lado_pct: 40, votacoes_em_comum: 30 }], result[:pares]
    assert_nil result[:fora_da_matriz]
    assert_includes result[:acoes].pluck(:rotulo), "Com quem o MDB mais vota"
  end

  test "destaques com os mesmos textos da página" do
    result = @tool.call("section" => "insights")

    assert_equal(@comparison.insights.map { |_, title, text| { titulo: title, texto: text } }, result[:destaques])
  end

  test "oferece a página da comparação, descartada quando o usuário já está nela" do
    result = @tool.call("section" => "blocs")
    page = result[:acoes].find { |action| action[:tipo] == "página" }

    assert_equal "/parties/compare", @tool.actions.find(page[:id]).value
    picked = @tool.actions.pick(result[:acoes].pluck(:id), current_path: "/parties/compare?sort=seats")
    assert_equal ["Partidos mais governistas"], picked.pluck("label")
  end

  test "recusa seção desconhecida, inclusive a tabela, que fica com party_ranking" do
    assert @tool.call("section" => "indicators")[:erro]
    assert_includes PartyComparisonTool.new.description, "party_ranking"
  end

  private

  def tool_for(comparison)
    PartyComparisonTool.new.tap { |tool| tool.define_singleton_method(:comparison) { comparison } }
  end

  # Linha da comparação com governismo e coesão escolhidos, para montar o mapa e a matriz
  def row(base, governism:, cohesion:, label: nil, id: nil)
    party = label ? Party.new(id: id, label: label, name: label) : base.party
    bloc = governism && PartyComparison::BLOCS.find { |_, data| governism >= data[:min] }.first
    PartyComparison::Row.new(party: party, seats: base.seats, cohesion: cohesion, bloc: bloc || PartyComparison::NO_DATA,
                             governism: governism && { followed: governism * 40 / 100, total: 40, pct: governism })
  end
end
