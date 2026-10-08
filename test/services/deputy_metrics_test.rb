require "test_helper"

class DeputyMetricsTest < ActiveSupport::TestCase
  test "usa o ano mais recente com despesas como referência" do
    assert_equal 2025, DeputyMetrics.reference_year
  end

  test "calcula gasto total e médio mensal de todos os deputados" do
    expenses = DeputyMetrics.expenses(2025)
    assert_equal({ total: 1000, months: 2, monthly: 500 }, expenses[deputies(:ana).id])
    assert_equal 3000, expenses.dig(deputies(:bruno).id, :monthly)
    assert_nil expenses[deputies(:carla).id]
  end

  test "posiciona o deputado no ranking da Câmara e do estado" do
    assert_equal({ position: 2, total: 2, state_position: 2, state_total: 2 },
                 DeputyMetrics.expense_rank(deputies(:ana), 2025))
    assert_nil DeputyMetrics.expense_rank(deputies(:carla), 2025)
  end

  test "calcula o uso da cota pelos meses de exercício" do
    quota = DeputyMetrics.quota_usage(deputies(:ana), 2025)
    assert_equal 2, quota[:months] # de março (1ª despesa) a abril (último mês com dados)
    assert_in_delta 42_837.33 * 2, quota[:quota], 0.01
    assert_equal 1, quota[:pct]
  end

  test "participação em lote bate com a individual" do
    deputy = deputies(:ana)
    bulk = DeputyMetrics.participation[deputy.id]
    assert_equal DeputyStats.new(deputy).vote_participation, bulk
  end

  test "alinhamento em lote bate com o individual" do
    %i[ana bruno carla davi].each do |name|
      deputy = deputies(name)
      expected = DeputyStats.new(deputy).party_alignment
      bulk = DeputyMetrics.alignment[deputy.id] || { aligned: 0, total: 0, against: 0, pct: nil }
      assert_equal expected, bulk, name
    end
  end

  test "calcula a coesão do partido pelo índice de Rice" do
    cohesion = DeputyMetrics.party_cohesion[parties(:mdb).id]
    # first: 3 Sim → 1; second: 1 Sim × 2 Não → 1/3; média ≈ 0,67
    assert_equal 67, cohesion[:pct]
    assert_equal 2, cohesion[:polls]
    assert_equal 1, cohesion[:unanimous]
    assert_in_delta 1 / 3.0, cohesion[:by_poll][polls(:second).id][:index], 0.001
    assert_equal({ sim: 1, nao: 2 }, cohesion[:by_poll][polls(:second).id].slice(:sim, :nao))
  end

  test "ignora votações com poucos votantes do partido" do
    assert_nil DeputyMetrics.party_cohesion[parties(:pt).id] # só davi votou
    assert_equal 67, DeputyMetrics.average_cohesion
  end

  test "conta votações em que dois deputados votaram diferente" do
    assert_equal({ common: 2, different: 1, pct: 50 }, DeputyMetrics.divergence(deputies(:ana), deputies(:bruno)))
    assert_equal({ common: 0, different: 0, pct: nil }, DeputyMetrics.divergence(deputies(:ana), deputies(:davi)))
  end
end
