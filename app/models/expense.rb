class Expense < ApplicationRecord
  belongs_to :deputy

  # Agrupa gastos por fornecedor pelo CNPJ/CPF (o mesmo fornecedor aparece com
  # nomes diferentes); sem documento (ex.: passagens aéreas), cai no nome.
  SUPPLIER_KEY = Arel.sql("COALESCE(NULLIF(supplier_cnpj_cpf, ''), supplier)")
  # Nome mais frequente do fornecedor dentro do grupo
  SUPPLIER_NAME = Arel.sql("MODE() WITHIN GROUP (ORDER BY supplier)")

  validates :expense_type, :document_amount, :year, :month, presence: true # passagens aéreas vêm sem cnpj/cpf
  validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :document_amount, :net_amount, numericality: true # estornos vêm negativos
end
