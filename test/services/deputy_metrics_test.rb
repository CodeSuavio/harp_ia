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

  test "conta votações em que dois deputados votaram diferente" do
    assert_equal({ common: 2, different: 1, pct: 50 }, DeputyMetrics.divergence(deputies(:ana), deputies(:bruno)))
    assert_equal({ common: 0, different: 0, pct: nil }, DeputyMetrics.divergence(deputies(:ana), deputies(:davi)))
  end
end
