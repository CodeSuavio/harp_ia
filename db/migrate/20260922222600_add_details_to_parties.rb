class AddDetailsToParties < ActiveRecord::Migration[8.1]
  def change
    add_column :parties, :label, :string
    add_column :parties, :name, :string
    add_column :parties, :url, :string
  end
end
