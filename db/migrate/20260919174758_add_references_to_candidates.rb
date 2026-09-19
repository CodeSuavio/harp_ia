class AddReferencesToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_reference :candidates, :party, null: false, foreign_key: true
    add_reference :candidates, :current_deputy, foreign_key: { to_table: :deputies }
  end
end
