require "test_helper"

class DeputyPanoramaToolTest < ActiveSupport::TestCase
  setup do
    # As fixtures têm só 3 votações; o mínimo real (20) deixaria todos sem governismo
    @panorama = DeputyPanorama.new(min_government_polls: 1)
    @tool = tool_for(@panorama)
  end

  test "blocos com as mesmas contagens da página e quem está fora do bloco do partido" do
    result = @tool.call("section" => "blocs")

    assert_equal "A Câmara em blocos, deputado a deputado", result[:secao]
    assert_equal DeputyPanorama::SECTIONS["blocs"][:how], result[:como_e_calculado]
    counts = @panorama.blocs.except(DeputyPanorama::NO_DATA).values.pluck(:count)
    assert_equal counts, result[:blocos].pluck(:deputados)
    assert_equal DeputyPanorama::MAJORITY, result[:maioria_absoluta]
    # No MDB, Bruno e Carla são de centro; Ana é governista
    assert_equal 1, result[:fora_do_bloco_do_partido][:total]
    assert_equal({ nome: "Ana Souza", bloco: "Governista", bloco_da_maioria_do_partido: "Centro" },
                 result[:fora_do_bloco_do_partido][:deputados].first.slice(:nome, :bloco, :bloco_da_maioria_do_partido))
  end

  test "blocos e destaques mostram a Câmara inteira, como a página, mesmo com filtros" do
    %w[blocs insights].each do |section|
      filtered = @tool.call("section" => section, "state" => "RJ")

      assert_match(/Câmara inteira/, filtered[:aviso])
      assert_equal tool_for(@panorama).call("section" => section).except(:acoes), filtered.except(:aviso, :acoes)
    end
  end

  test "destaques com os mesmos textos da página" do
    result = @tool.call("section" => "insights")

    assert_equal(@panorama.insights.map { |_, title, text| { titulo: title, texto: text } }, result[:destaques])
    assert_nil result[:aviso]
  end

  test "tabela sem filtro: todos os deputados, médias da Câmara e ranking de governismo" do
    result = @tool.call("section" => "indicators")

    assert_equal 4, result[:deputados_exibidos]
    assert_equal 4, result[:com_governismo_calculado]
    assert_equal @panorama.total, result[:de]
    assert_nil result[:media_do_filtro]
    assert_equal @panorama.averages[:governism_pct].round, result[:media_da_camara][:governismo_pct]
    assert_equal(%w[Ana Carla Bruno Davi], result[:ranking_por_governismo].map { |row| row[:nome].split.first })
  end

  test "tabela com os filtros da página: quantos aparecem e a média do recorte" do
    result = @tool.call("section" => "indicators", "state" => "rj")
    rows = @panorama.sorted_rows("governism", :desc, state: "RJ")

    assert_equal({ uf: "RJ" }, result[:filtros])
    assert_equal 2, result[:deputados_exibidos]
    assert_equal @panorama.averages(rows)[:governism_pct].round, result[:media_do_filtro][:governismo_pct]

    by_party = @tool.call("section" => "indicators", "party" => "pt")
    assert_equal({ partido: "PT" }, by_party[:filtros])
    assert_equal(["Davi Rocha"], by_party[:ranking_por_governismo].pluck(:nome))
  end

  test "ranking cortado continua pela Harpia e leva à tabela com os mesmos filtros" do
    result = @tool.call("section" => "indicators", "state" => "RJ", "order" => "asc", "limit" => 1)

    assert_equal(["Davi Rocha"], result[:ranking_por_governismo].pluck(:nome))
    assert_equal({ exibindo: 1, de: 2 }, result[:recorte])
    assert_equal 2, result[:com_governismo_calculado]
    page = @tool.actions.find(result[:acoes].first[:id])
    assert_equal "/deputies/compare?dir=asc&state=RJ", page.value
    # O ranking acompanha a contagem: a continuação só entra se a resposta mostrou a lista
    assert_empty @tool.actions.pick([], content: "No RJ, a tabela mostra 2 deputados.")
    assert_equal ["Ver lista completa"], @tool.actions.pick([], content: "1. Davi Rocha").pluck("label")
  end

  test "o link da tabela é descartado quando o usuário já está nela" do
    result = @tool.call("section" => "indicators", "state" => "RJ")
    picked = @tool.actions.pick(result[:acoes].pluck(:id), current_path: "/deputies/compare?state=RJ&page=2")

    assert_empty picked
  end

  test "mapa resumido por bloco; com filtro, lista os pontos do recorte" do
    result = @tool.call("section" => "positioning")

    assert_equal @panorama.positioned.size, result[:deputados_no_mapa]
    assert_equal @panorama.positioned.size, result[:por_bloco].pluck(:deputados).sum
    assert_nil result[:recorte_do_mapa]

    slice = @tool.call("section" => "positioning", "party" => "MDB")[:recorte_do_mapa]
    mdb = @panorama.positioned.select { |row| row.party_label == "MDB" }
                   .sort_by { |row| [-row.governism_pct, row.name] }
    expected = mdb.map { |row| [row.name, row.governism_pct, row.alignment_pct] }
    listed = slice[:deputados].map { |row| row.values_at(:nome, :governismo_pct, :alinhamento_pct) }
    assert_equal expected, listed
    assert_match(/página mostra todos/, slice[:observacao])
    assert_equal mdb.size, slice[:no_mapa]
    # Davi, único deputado do PT, não tem alinhamento ao partido: fica fora do mapa
    pt = @tool.call("section" => "positioning", "party" => "PT")[:recorte_do_mapa]
    assert_equal [0, 1], pt.values_at(:no_mapa, :fora_do_mapa)
  end

  test "sem deputados suficientes o mapa não é exibido" do
    assert_match(/não é exibido/, tool_for(DeputyPanorama.new).call("section" => "positioning")[:aviso])
  end

  test "recusa seção, partido e UF desconhecidos" do
    assert @tool.call("section" => "mapa")[:erro]
    assert @tool.call("section" => "indicators", "party" => "XYZ")[:erro]
    assert @tool.call("section" => "indicators", "state" => "XX")[:erro]
  end

  test "deixa os rankings por outros indicadores com deputy_ranking" do
    assert_includes DeputyPanoramaTool.new.description, "deputy_ranking"
  end

  private

  def tool_for(panorama)
    DeputyPanoramaTool.new.tap { |tool| tool.define_singleton_method(:panorama) { panorama } }
  end
end
