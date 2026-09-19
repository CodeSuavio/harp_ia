class CreateBills < ActiveRecord::Migration[8.1]
  def change
    create_table :bills do |t|
      t.timestamps
    end
  end
end
