class ChangeExpenseDocumentDateToDateTime < ActiveRecord::Migration[8.1]
  def up
    change_column :expenses, :document_date, :datetime
  end

  def down
    change_column :expenses, :document_date, :date
  end
end
