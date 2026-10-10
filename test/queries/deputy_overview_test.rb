require "test_helper"

class DeputyOverviewTest < ActiveSupport::TestCase
  test "maiores fornecedores agrupa pelo CNPJ, não pelo nome" do
    deputies(:ana).expenses.create!(year: 2025, month: 4, expense_type: "COMBUSTÍVEIS E LUBRIFICANTES.",
                                    supplier: "POSTO CENTRAL LTDA", supplier_cnpj_cpf: "00.000.000/0001-00",
                                    document_amount: 800, net_amount: 800)
    top = DeputyOverview.new(deputies(:ana)).top_suppliers

    posto = top.find { |_, total, _| total == 1100 } # 300 + 800, mesmo CNPJ
    assert posto
    assert_equal 2, posto.last
  end
end
