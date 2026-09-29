class RemoveUnrelatedIdsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_reference :users, :bill, null: false, foreign_key: true
    remove_reference :users, :candidate, null: false, foreign_key: true
    remove_reference :users, :deputy, null: false, foreign_key: true
    remove_reference :users, :party, null: false, foreign_key: true
  end
end
