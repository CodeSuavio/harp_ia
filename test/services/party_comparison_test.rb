require "test_helper"

class PartyComparisonTest < ActiveSupport::TestCase
  setup do
    # As fixtures têm só 3 votações; o mínimo real (20) deixaria todos sem governismo
    @comparison = PartyComparison.new(min_government_polls: 1)
  end

  test "monta uma linha por partido com bancada, da maior para a menor" do
    assert_equal %w[MDB PT], @comparison.rows.map(&:label)

    mdb = @comparison.rows.first
    assert_equal 3, mdb.seats
    assert_equal 2, mdb.states
    assert_equal({ state: "SP", seats: 2, pct: 67 }, mdb.top_state)
    assert_equal 67, mdb.cohesion
    assert_equal 50, mdb.adherence
    assert_equal 1750, mdb.monthly # (500 + 3000) / 2, Carla sem despesa
    assert_equal 1, mdb.candidates
  end

  test "mede o governismo pela orientação do Governo e classifica em blocos" do
    mdb, pt = @comparison.rows

    assert_equal({ followed: 1, total: 2, pct: 50 }, mdb.governism)
    assert_equal :center, mdb.bloc
    assert_equal 0, pt.governism_pct # Davi votou Sim; o Governo orientou Não
    assert_equal :opposition, pt.bloc

    assert_equal 3, @comparison.blocs[:center][:seats]
    assert_equal 1, @comparison.blocs[:opposition][:seats]
    assert_equal 0, @comparison.blocs[:government][:seats]
  end

  test "sem votações suficientes o partido fica sem bloco" do
    comparison = PartyComparison.new
    assert(comparison.rows.all? { |row| row.governism.nil? && row.bloc == PartyComparison::NO_DATA })
    assert_empty comparison.positioned
  end

  test "ordena pela coluna pedida, com quem não tem o dado por último" do
    assert_equal %w[PT MDB], @comparison.sorted_rows("seats", :asc).map(&:label)
    assert_equal %w[MDB PT], @comparison.sorted_rows("governism", :desc).map(&:label)
    assert_equal %w[MDB PT], @comparison.sorted_rows("cohesion", :asc).map(&:label) # PT sem coesão
  end

  test "gera destaques a partir dos números" do
    titles = @comparison.insights.map(&:second)
    assert_includes titles, "Quem decide as votações"
    assert_includes titles, "Do mais governista ao mais oposicionista"

    extremes = @comparison.insights.find { |_, title, _| title == "Do mais governista ao mais oposicionista" }
    assert_match(/MDB acompanhou o Governo em 50%.*PT, em apenas 0%/, extremes.last)
  end

  # Troca DeputyMetrics.party_affinity por uma matriz montada no teste e restaura no fim
  # (as fixtures têm só 3 votações, abaixo do mínimo de votações em comum)
  def with_party_affinity(matrix)
    original = DeputyMetrics.method(:party_affinity)
    DeputyMetrics.define_singleton_method(:party_affinity) { matrix }
    yield
  ensure
    DeputyMetrics.define_singleton_method(:party_affinity, original)
  end

  test "matriz de afinidade tira quem não tem votações suficientes em comum e lista à parte" do
    mdb, pt = parties(:mdb), parties(:pt)
    matrix = lambda do |common|
      cell = { same: common / 2, common: common, pct: 50 }
      { mdb.id => { pt.id => cell }, pt.id => { mdb.id => cell } }
    end

    with_party_affinity(matrix.call(PartyStats::AFFINITY_MIN_POLLS)) do
      affinity = PartyComparison.new(min_government_polls: 1).affinity
      assert_equal %w[MDB PT], affinity[:parties].map(&:label).sort
      assert_empty affinity[:left_out]
    end

    # Abaixo do mínimo, a linha e a coluna seriam só "·": os dois saem da matriz
    with_party_affinity(matrix.call(PartyStats::AFFINITY_MIN_POLLS - 1)) do
      affinity = PartyComparison.new(min_government_polls: 1).affinity
      assert_empty affinity[:parties]
      assert_equal %w[MDB PT], affinity[:left_out].map(&:label)
    end

    # Partido sem dado de votação nenhum também vai para a lista
    with_party_affinity({}) do
      assert_equal %w[MDB PT], PartyComparison.new.affinity[:left_out].map(&:label)
    end
  end
end
