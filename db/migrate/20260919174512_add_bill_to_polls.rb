class AddBillToPolls < ActiveRecord::Migration[8.1]
  def change
    add_reference :polls, :bill, null: false, foreign_key: true
  end
end
