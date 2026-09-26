class AddCamaraIdToParties < ActiveRecord::Migration[8.1]
  def change
    add_column :parties, :camara_id, :integer
  end
end
