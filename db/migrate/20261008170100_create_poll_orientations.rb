class CreatePollOrientations < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_orientations do |t|
      t.references :poll, null: false, foreign_key: true
      t.references :party, foreign_key: true
      t.string :label, null: false
      t.string :orientation, null: false
      t.timestamps
    end
    add_index :poll_orientations, [:poll_id, :label], unique: true
  end
end
