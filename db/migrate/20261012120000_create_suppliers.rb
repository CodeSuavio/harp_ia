class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :cnpj, null: false
      t.string :name
      t.string :cnae_code
      t.string :cnae_description
      t.jsonb :secondary_cnaes, null: false, default: []
      t.string :registration_status
      t.date :registration_status_date
      t.datetime :fetched_at
      t.string :fetch_error

      t.timestamps
    end
    add_index :suppliers, :cnpj, unique: true
  end
end
