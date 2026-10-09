require "test_helper"

class PartyStatsTest < ActiveSupport::TestCase
  setup do
    @mdb = PartyStats.new(parties(:mdb))
    @pt = PartyStats.new(parties(:pt))
  end

  test "agrupa a bancada por estado, do maior para o menor" do
    assert_equal [["SP", 2], ["RJ", 1]], @mdb.state_bench
  end

  test "soma os gastos da bancada e compara a média mensal com a da Câmara" do
    expenses = @mdb.expenses
    assert_equal 2025, expenses[:year]
    assert_equal 4000, expenses[:total]
    assert_equal 2, expenses[:deputies] # Carla não tem despesa
    assert_equal 1750, expenses[:monthly] # (500 + 3000) / 2
    assert_equal 1750, expenses[:chamber_monthly]
    assert_equal deputies(:bruno), expenses[:top].first.first
    assert_equal "COMBUSTÍVEIS E LUBRIFICANTES.", expenses[:types].first.first
    assert_nil @pt.expenses
  end

  test "mede quanto a bancada seguiu a orientação da liderança" do
    adherence = @mdb.orientation_adherence
    assert_equal 1, adherence[:followed]
    assert_equal 2, adherence[:total]
    assert_equal 50, adherence[:pct]
    assert_equal [polls(:second)], adherence[:against].map(&:first)
  end

  test "usa a orientação da federação quando o partido não orienta sozinho" do
    assert_equal({ polls(:third).id => "Não" }, @pt.orientations)
    assert_equal "PT-PCdoB-PV", @pt.federation[:label]
    assert_equal [parties(:pt)], @pt.federation[:parties]
    assert_nil @mdb.federation
  end

  test "lista quem mais vota contra a maioria do partido" do
    dissidents = @mdb.dissidents(min_votes: 2)
    assert_equal [deputies(:ana)], dissidents.map(&:first)
    assert_equal({ aligned: 1, total: 2, against: 1, pct: 50 }, dissidents.first.last)
    assert_empty @mdb.dissidents # poucos votos para o mínimo padrão
  end

  test "mostra a posição da bancada nas votações mais apertadas, da mais recente para a mais antiga" do
    rows = @mdb.contested_polls
    assert_equal [polls(:second), polls(:first)], rows.map(&:first)
    assert_equal({ sim: 1, nao: 2 }, rows.first.last[:party].slice(:sim, :nao))
    assert_equal "Sim", rows.first.last[:orientation]
    assert_empty @pt.contested_polls # sem coesão (bancada pequena)
  end

  test "compara as maiorias de cada par de partidos" do
    cohesion = {
      1 => { by_poll: { 10 => { sim: 3, nao: 0 }, 11 => { sim: 0, nao: 3 }, 12 => { sim: 2, nao: 2 } } },
      2 => { by_poll: { 10 => { sim: 3, nao: 1 }, 11 => { sim: 3, nao: 0 }, 12 => { sim: 3, nao: 0 } } }
    }
    affinity = DeputyMetrics.affinity_from(cohesion)
    # A votação 12 não entra: o partido 1 empatou
    assert_equal({ same: 1, common: 2, pct: 50 }, affinity[1][2])
    assert_equal affinity[1][2], affinity[2][1]
  end

  test "resume projetos e propostas do partido" do
    assert_equal 1, @mdb.bills.count
    assert_equal [[themes(:transparencia), 1]], @mdb.bill_themes
    assert_equal [proposals(:mdb_transparencia)], @mdb.proposals.to_a
  end

  test "traça o perfil das candidaturas de 2026" do
    profile = @mdb.candidate_profile
    assert_equal 1, profile[:total]
    assert_equal 1, profile[:reelection]
    assert_equal [[PartyStats::NOT_INFORMED, 1]], profile[:gender]
    assert_equal [["SP", 1]], profile[:states]
    assert_nil @pt.candidate_profile
  end

  test "lista os partidos que se fundiram a este" do
    assert_equal %w[DEM PSL], Party.new(label: "UNIÃO").absorbed.keys
    assert_empty parties(:mdb).absorbed
  end
end
