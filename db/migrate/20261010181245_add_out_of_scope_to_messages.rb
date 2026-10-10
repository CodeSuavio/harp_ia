class AddOutOfScopeToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :out_of_scope, :boolean, default: false, null: false
  end
end
