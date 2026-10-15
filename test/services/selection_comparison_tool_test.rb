require "test_helper"

class SelectionComparisonToolTest < ActiveSupport::TestCase
  setup do
    @mdb = parties(:mdb)
    @pt = parties(:pt)
    @tool = SelectionComparisonTool.new
  end

  # ----- PARTIDOS -----

  test "partidos: mesma tabela da página, na ordem escolhida, por sigla ou id" do
    result = @tool.call("kind" => "partidos", "ids" => "pt, #{@mdb.id}")
    selection = PartySelectionComparison.for([@pt.id, @mdb.id])

    assert_equal %w[PT MDB], result[:escolhidos].pluck(:nome)
    assert_equal selection.rows.map(&:label), result[:linhas].pluck(:indicador)
    deputies = result[:linhas].find { |line| line[:indicador] == "Deputados" }
    assert_equal [1, 3], deputies[:valores].pluck(:valor)
    assert_equal PartySelectionComparison::SECTIONS["table"][:reading], result[:como_ler]
  end

  test "partidos: melhor e pior só nas linhas com direção, como a página marca" do
    result = @tool.call("kind" => "partidos", "ids" => "MDB, PT")
    selection = PartySelectionComparison.for([@mdb.id, @pt.id])

    selection.rows.each do |row|
      line = result[:linhas].find { |item| item[:indicador] == row.label }
      best = selection.parties.find { |party| selection.highlight(row, party) == :best }
      best ? assert_equal(best.label, line[:melhor], row.label) : assert_nil(line[:melhor], row.label)
      assert_nil line[:conta_como_melhor], row.label unless row.better
    end
  end

  test "partidos: os pares dizem que mede votos iguais" do
    pair = @tool.call("kind" => "partidos", "ids" => "MDB, PT")[:como_votaram_entre_si][:pares].first

    assert_equal "MDB e PT", pair[:partidos]
    # Nas fixtures as bancadas têm poucas votações em comum
    assert_equal "poucas votações em comum para comparar", pair[:aviso]
    assert_match(/maioria das duas/, @tool.call("kind" => "partidos", "ids" => "MDB, PT")
                                         .dig(:como_votaram_entre_si, :como_e_calculado))
  end

  test "partidos: aceita sigla sem acento e aponta o que não encontrou" do
    result = @tool.call("kind" => "partidos", "ids" => "mdb, pt, XYZ")

    assert_equal %w[MDB PT], result[:escolhidos].pluck(:nome)
    assert_equal ["XYZ"], result[:nao_encontrados]
  end

  test "partidos: link para a mesma comparação, descartado quando o usuário já está nela" do
    result = @tool.call("kind" => "partidos", "ids" => "MDB, PT")
    page = result[:acoes].find { |action| action[:rotulo] == "Ver comparação dos partidos" }

    path = @tool.actions.find(page[:id]).value
    assert_equal "/parties/compare?ids%5B%5D=#{@mdb.id}&ids%5B%5D=#{@pt.id}", path
    current = "/parties/compare?ids[]=#{@mdb.id}&ids[]=#{@pt.id}"
    assert_not_includes @tool.actions.pick([page[:id]], current_path: current).pluck("label"), page[:rotulo]
  end

  # ----- DEPUTADOS -----

  test "deputados: mesma tabela e a divergência entre cada par, na ordem escolhida" do
    ana, bruno, davi = %i[ana bruno davi].map { |name| deputies(name) }
    result = @tool.call("kind" => "deputados", "ids" => "#{davi.id}, #{ana.id}, #{bruno.id}")
    comparison = DeputyComparison.for([davi.id, ana.id, bruno.id])

    assert_equal [davi.name, ana.name, bruno.name], result[:escolhidos].pluck(:nome)
    assert_equal comparison.rows.map(&:label), result[:linhas].pluck(:indicador)
    expected = comparison.divergences.map { |_, _, divergence| divergence[:pct] }
    pairs = result[:como_votaram_entre_si][:pares]
    assert_equal "#{davi.name} e #{ana.name}", pairs.first[:deputados]
    assert_equal expected, pairs.pluck(:votaram_diferente_pct)
    assert_includes result[:acoes].pluck(:rotulo), "Ver perfil de #{ana.name}"
  end

  test "deputados: só por id; nomes vão para search_platform" do
    result = @tool.call("kind" => "deputados", "ids" => "Ana, #{deputies(:bruno).id}")

    assert_match(/ao menos 2/, result[:erro])
    assert_equal ["Ana"], result[:nao_encontrados]
    assert_includes SelectionComparisonTool.new.description, "search_platform"
  end

  test "respeita o limite da página e avisa" do
    ids = %i[ana bruno carla davi].map { |name| deputies(name).id }.join(", ")
    result = @tool.call("kind" => "deputados", "ids" => ids)

    assert_equal DeputyComparison::LIMIT, result[:escolhidos].size
    assert_match(/até #{DeputyComparison::LIMIT}/, result[:aviso])
  end

  test "recusa tipo desconhecido e menos de 2 registros" do
    assert @tool.call("kind" => "candidatos", "ids" => "1, 2")[:erro]
    assert @tool.call("kind" => "partidos", "ids" => "PT")[:erro]
  end
end
