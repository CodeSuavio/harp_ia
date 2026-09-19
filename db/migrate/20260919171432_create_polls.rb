class CreatePolls < ActiveRecord::Migration[8.1]
  def change
    create_table :polls do |t|
      t.timestamps
    end
  end
end
