require "test_helper"

class ExpenseAnomaliesTest < ActiveSupport::TestCase
  FUEL = "COMBUSTÍVEIS E LUBRIFICANTES."
  OFFICE = "MANUTENÇÃO DE ESCRITÓRIO DE APOIO À ATIVIDADE PARLAMENTAR"
  CNPJ = "12.345.678/0001-90"

  setup do
    @carla = deputies(:carla) # sem despesas nas fixtures
  end

  test "sem nada fora do padrão a lista fica vazia" do
    assert_empty ExpenseAnomalies.new(deputies(:ana)).for_year(2025)
  end

  test "aponta a mesma nota lançada mais de uma vez" do
    2.times { expense(@carla, net_amount: 800, document_url: "https://camara.leg.br/nota/1") }
    expense(@carla, net_amount: 800, document_url: "https://camara.leg.br/nota/2")

    row = find(@carla, :duplicate_document)
    assert_equal [2, 1600, :high], row.values_at(:count, :value, :severity)
  end

  test "aponta várias notas do mesmo fornecedor no mesmo dia" do
    4.times { expense(@carla, net_amount: 1500, document_date: "2025-03-10") }
    row = find(@carla, :split_notes)
    assert_equal [4, 6000, 3], row.values_at(:count, :value, :month)

    # Abaixo do mínimo de notas não marca
    3.times { expense(deputies(:davi), net_amount: 3000, document_date: "2025-03-10") }
    assert_nil find(deputies(:davi), :split_notes)
  end

  test "aponta notas mais caras que quase todas do mesmo tipo na Câmara" do
    note = expense(@carla, net_amount: 9000, supplier_cnpj_cpf: nil)
    row = find(@carla, :atypical_note)
    assert_equal [FUEL, [note.id]], row.values_at(:expense_type, :expense_ids)
    assert_operator row[:reference], :<, 9000
  end

  test "aponta mês muito acima da mediana do próprio deputado" do
    (1..4).each { |month| expense(@carla, expense_type: OFFICE, month: month, net_amount: 1000, supplier_cnpj_cpf: nil) }
    expense(@carla, expense_type: OFFICE, month: 5, net_amount: 2600, supplier_cnpj_cpf: nil)
    expense(@carla, expense_type: OFFICE, month: 6, net_amount: 2400, supplier_cnpj_cpf: nil)

    peaks = ExpenseAnomalies.new(@carla).for_year(2025).select { |row| row[:kind] == :month_peak }
    assert_equal([[5, 1000]], peaks.map { |row| row.values_at(:month, :reference) })
  end

  test "com poucos meses não aponta pico" do
    expense(@carla, month: 1, net_amount: 100, supplier_cnpj_cpf: nil)
    expense(@carla, month: 2, net_amount: 5000, supplier_cnpj_cpf: nil)
    assert_nil find(@carla, :month_peak)
  end

  test "aponta tipo de despesa que disparou em relação ao ano anterior" do
    expense(@carla, expense_type: OFFICE, year: 2024, month: 1, net_amount: 10_000, supplier_cnpj_cpf: nil)
    expense(@carla, expense_type: OFFICE, month: 1, net_amount: 35_000, supplier_cnpj_cpf: nil)

    row = find(@carla, :type_jump)
    assert_equal [OFFICE, 35_000, 10_000], row.values_at(:expense_type, :value, :reference)
  end

  test "aponta empresa que só atende o deputado" do
    expense(@carla, expense_type: OFFICE, net_amount: 250_000)
    assert_equal 250_000, find(@carla, :exclusive_supplier)[:value]

    # Se outro deputado também usa a empresa, deixa de ser exclusiva
    expense(deputies(:davi), expense_type: OFFICE, net_amount: 100)
    assert_nil find(@carla, :exclusive_supplier)
  end

  test "aponta fornecedor novo de valor alto" do
    expense(@carla, year: 2024, supplier: "Antigo", supplier_cnpj_cpf: "11.111.111/0001-11", net_amount: 100)
    expense(@carla, expense_type: OFFICE, supplier: "Antigo", supplier_cnpj_cpf: "11.111.111/0001-11", net_amount: 60_000)
    expense(@carla, expense_type: OFFICE, supplier: "Novo", net_amount: 60_000)

    rows = ExpenseAnomalies.new(@carla).for_year(2025).select { |row| row[:kind] == :new_supplier }
    assert_equal(["Novo"], rows.map { |row| row[:supplier] })
  end

  test "ordena por gravidade" do
    2.times { expense(@carla, net_amount: 800, document_url: "https://camara.leg.br/nota/1") }
    expense(@carla, expense_type: OFFICE, net_amount: 250_000)

    assert_equal %i[high low], ExpenseAnomalies.new(@carla).for_year(2025).map { |row| row[:severity] }.uniq
  end

  private

  def expense(deputy, **attributes)
    Expense.create!({ deputy: deputy, year: 2025, month: 3, expense_type: FUEL, supplier: "Fornecedor",
                      supplier_cnpj_cpf: CNPJ, document_amount: attributes.fetch(:net_amount, 100),
                      net_amount: 100, document_date: "2025-03-01" }.merge(attributes))
  end

  def find(deputy, kind)
    ExpenseAnomalies.new(deputy).for_year(2025).find { |row| row[:kind] == kind }
  end
end
