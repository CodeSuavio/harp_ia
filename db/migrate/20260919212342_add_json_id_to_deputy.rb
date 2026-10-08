class AddJsonIdToDeputy < ActiveRecord::Migration[8.1]
  def change
    add_column :deputies, :json_id, :bigint
    add_index :deputies, :json_id, unique: true
  end
end
