class CreateSolidCableMessages < ActiveRecord::Migration[8.1]
  # Tabela do Solid Cable, adaptador do WebSocket em produção (config/cable.yml).
  #
  # Em produção, o banco "cable" usa o mesmo DATABASE_URL do principal, então a
  # tabela é criada por esta migration, junto com as demais, em vez de pelo
  # db/cable_schema.rb. Mesma estrutura do db/cable_schema.rb.
  def change
    create_table :solid_cable_messages, if_not_exists: true do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false
      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
