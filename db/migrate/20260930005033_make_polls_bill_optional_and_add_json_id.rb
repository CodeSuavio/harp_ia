class MakePollsBillOptionalAndAddJsonId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :polls, :bill_id, true
    add_column :polls, :json_id, :string
    add_index :polls, :json_id, unique: true
  end
end
