# Gastos de um deputado num ano como a aba Gastos do perfil mostra: o total
# de cada mês, os principais fornecedores e a ordem da lista de notas.
#
# Usado pela página (DeputiesController#load_expenses) e pela Harpia
# (DeputyDetailsTool), para os números serem os mesmos nas duas.
class DeputyExpenseBreakdown
  SUPPLIERS_LIMIT = 10
  # Lista de notas: das mais recentes para as mais antigas
  NOTES_ORDER = { document_date: :desc, id: :desc }.freeze

  # expenses: as despesas do deputado no ano
  def initialize(expenses)
    @expenses = expenses
  end

  # { mês => total líquido }
  def monthly
    @expenses.group(:month).sum(:net_amount)
  end

  # [[fornecedor, CNPJ/CPF, total, notas]], de quem mais recebeu para quem menos recebeu
  def top_suppliers(limit = SUPPLIERS_LIMIT)
    @expenses.group(Expense::SUPPLIER_KEY)
             .order(Arel.sql("SUM(net_amount) DESC"))
             .limit(limit)
             .pluck(Expense::SUPPLIER_NAME, Arel.sql("MAX(supplier_cnpj_cpf)"),
                    Arel.sql("SUM(net_amount)"), Arel.sql("COUNT(*)"))
  end

  def notes
    @expenses.order(NOTES_ORDER)
  end
end
