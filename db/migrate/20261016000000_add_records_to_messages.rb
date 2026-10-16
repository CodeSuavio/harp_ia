# Deputados e partidos que cada resposta da Harpia apresentou (HarpiaRecords),
# para entender "esses deputados" ou "qual deles" nas perguntas seguintes
class AddRecordsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :records, :jsonb, default: [], null: false
  end
end
