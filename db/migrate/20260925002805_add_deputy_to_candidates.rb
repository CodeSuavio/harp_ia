class AddDeputyToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_reference :candidates, :current_deputy, type: :bigint, index: true, foreign_key: { to_table: :deputies, primary_key: :json_id }
  end
end
