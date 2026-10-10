class CreatePartyAffiliations < ActiveRecord::Migration[8.1]
  def change
    create_table :party_affiliations do |t|
      t.references :deputy, null: false, foreign_key: true
      t.references :party, foreign_key: true
      t.string :party_label, null: false
      t.integer :legislature, null: false
      t.date :started_on, null: false
      t.string :kind, null: false
      t.timestamps
    end
    add_index :party_affiliations, [:deputy_id, :started_on]
  end
end
