class AddDeputyDashboardIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :deputies, :state_label
    add_index :deputies, :electoral_status
    add_index :expenses, [:deputy_id, :year, :month]
    add_index :votes, [:poll_id, :deputy_id], unique: true
  end
end
