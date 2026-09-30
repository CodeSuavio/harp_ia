class AddAttributesToParty < ActiveRecord::Migration[8.1]
  def change
    add_column :parties, :label, :string, if_not_exists: true
    add_column :parties, :name, :string, if_not_exists: true
    add_column :parties, :url, :string, if_not_exists: true
  end
end
