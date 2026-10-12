class CreateExpenseAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_alerts do |t|
      t.references :deputy, null: false, foreign_key: true, index: false
      t.integer :year, null: false
      t.string :kind, null: false
      t.string :severity, null: false
      t.decimal :value
      t.bigint :expense_ids, array: true, null: false, default: []
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end
    add_index :expense_alerts, [:deputy_id, :year]
    add_index :expense_alerts, [:year, :severity]
  end
end
