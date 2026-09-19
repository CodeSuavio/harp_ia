class AddPartyToDeputies < ActiveRecord::Migration[8.1]
  def change
    add_reference :deputies, :party, null: false, foreign_key: true
  end
end
