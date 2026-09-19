class AddReferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :candidate, null: false, foreign_key: true
    add_reference :users, :deputy, null: false, foreign_key: true
    add_reference :users, :party, null: false, foreign_key: true
    add_reference :users, :bill, null: false, foreign_key: true
  end
end
