class Expense < ApplicationRecord
  belongs_to :deputy

  validates :expense_type, :document_amount, :year, :month, presence: true # passagens aéreas vêm sem cnpj/cpf
  validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :document_amount, :net_amount, numericality: true # estornos vêm negativos
end
