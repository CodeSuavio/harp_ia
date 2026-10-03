require "test_helper"

class DeputyStatsTest < ActiveSupport::TestCase
  setup do
    @stats = DeputyStats.new(deputies(:ana))
  end

  test "soma os gastos líquidos" do
    assert_equal 1500, @stats.total_expenses
    assert_equal 1000, @stats.total_expenses(year: 2025)
    assert_equal 0, @stats.total_expenses(year: 2023)
  end

  test "gasto médio mensal considera só os meses com despesa" do
    assert_equal 500, @stats.monthly_average(year: 2025) # 1000 em 2 meses
  end

  test "compara a média mensal com a do estado e a do partido" do
    benchmarks = @stats.expense_benchmarks(year: 2025)
    assert_equal 1750, benchmarks[:state] # (500 + 3000) / 2 deputados de SP com gastos
    assert_equal 1750, benchmarks[:party]
  end

  test "compara com o mesmo período do ano anterior" do
    assert_equal({ previous: 500, pct: 100, last_month: 4 }, @stats.year_over_year(year: 2025))
    assert_nil DeputyStats.new(deputies(:bruno)).year_over_year(year: 2025)
  end

  test "compara cada tipo de despesa com a média da Câmara" do
    fuel = @stats.expenses_by_type(year: 2025).find { |row| row[:type].start_with?("COMBUST") }
    assert_equal 1650, fuel[:average] # (300 + 3000) / 2 deputados com gastos
    assert_equal 0.2, fuel[:ratio]
  end

  test "aponta concentração em um único fornecedor" do
    concentration = @stats.supplier_concentration(year: 2025)
    assert_equal "Imobiliária X", concentration[:supplier]
    assert_equal 70, concentration[:pct]
    assert concentration[:alert]
  end

  test "participação conta só as votações do período em que o deputado votou" do
    participation = @stats.vote_participation
    # A votação 3 é depois do último voto de Ana: não conta contra ela
    assert_equal [2, 2, 100], participation.values_at(:voted, :total, :pct)
  end

  test "sem votos a participação fica sem percentual" do
    assert_nil DeputyStats.new(Deputy.create!(name: "Sem votos", cpf: "55555555555", json_id: 9, state_label: "SP", party: parties(:pt)))
                          .vote_participation[:pct]
  end

  test "calcula o alinhamento com a maioria do partido" do
    assert_equal({ aligned: 1, total: 2, against: 1, pct: 50 }, @stats.party_alignment)
    assert_equal [polls(:second).id], @stats.against_party_poll_ids
  end

  test "sem votos Sim/Não o alinhamento fica sem percentual" do
    assert_nil DeputyStats.new(deputies(:davi)).party_alignment[:pct]
  end
end
