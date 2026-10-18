class CreateCampaignFinances < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_finances do |t|
      t.references :candidate, null: false, foreign_key: true, index: { unique: true }
      t.integer :votes
      t.integer :valid_votes
      t.string :result
      t.decimal :expenses, precision: 14, scale: 2
      t.integer :expenses_count
      t.decimal :revenues, precision: 14, scale: 2
      t.decimal :public_funds, precision: 14, scale: 2
      t.decimal :own_funds, precision: 14, scale: 2
      t.decimal :individual_donations, precision: 14, scale: 2
      t.string :accounts_kind
      t.jsonb :top_expenses, null: false, default: []

      t.timestamps
    end
  end
end
