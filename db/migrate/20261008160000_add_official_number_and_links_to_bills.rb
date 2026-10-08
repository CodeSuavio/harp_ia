class AddOfficialNumberAndLinksToBills < ActiveRecord::Migration[8.1]
  def change
    add_column :bills, :bill_type, :string
    add_column :bills, :number, :integer
    add_index :bills, [:bill_type, :number, :year], unique: true
    change_column_null :bills, :deputy_id, true
    change_column_null :bills, :party_id, true

    create_table :bill_authors do |t|
      t.references :bill, null: false, foreign_key: true
      t.references :deputy, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bill_authors, [:bill_id, :deputy_id], unique: true

    create_table :poll_bills do |t|
      t.references :poll, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.timestamps
    end
    add_index :poll_bills, [:poll_id, :bill_id], unique: true
  end
end
