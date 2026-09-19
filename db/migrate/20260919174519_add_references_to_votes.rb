class AddReferencesToVotes < ActiveRecord::Migration[8.1]
  def change
    add_reference :votes, :poll, null: false, foreign_key: true
    add_reference :votes, :deputy, null: false, foreign_key: true
  end
end
