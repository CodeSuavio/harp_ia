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
end
