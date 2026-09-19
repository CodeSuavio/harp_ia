class AddDetailsToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :year, :integer
    add_column :expenses, :month, :integer
    add_column :expenses, :expense_type, :string
    add_column :expenses, :supplier, :string
    add_column :expenses, :supplier_cnpj_cpf, :string
    add_column :expenses, :document_date, :date
    add_column :expenses, :document_amount, :decimal
    add_column :expenses, :net_amount, :decimal
    add_column :expenses, :document_url, :string
  end
end
