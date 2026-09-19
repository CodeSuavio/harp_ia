class Expense < ApplicationRecord
  belongs_to :deputy

  validates :expense_type, :document_amount, :year, :month, :supplier_cnpj_cpf, presence: true
  validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :document_amount, :net_amount, numericality: { greater_than_or_equal_to: 0 }
end
