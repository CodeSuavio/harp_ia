class CreateDeputies < ActiveRecord::Migration[8.1]
  def change
    create_table :deputies do |t|
      t.timestamps
    end
  end
end
