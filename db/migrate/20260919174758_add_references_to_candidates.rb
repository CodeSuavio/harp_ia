class AddReferencesToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_reference :candidates, :party, null: false, foreign_key: true
  end
end
