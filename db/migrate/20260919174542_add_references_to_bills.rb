class AddReferencesToBills < ActiveRecord::Migration[8.1]
  def change
    add_reference :bills, :deputy, null: false, foreign_key: true
    add_reference :bills, :party, null: false, foreign_key: true
  end
end
