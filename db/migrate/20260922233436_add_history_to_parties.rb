class AddHistoryToParties < ActiveRecord::Migration[8.1]
  def change
    add_column :parties, :number, :integer
    add_column :parties, :registered_on, :date
    add_column :parties, :active, :boolean
    add_column :parties, :former_labels, :string
    add_column :parties, :succeeded_by, :string
  end
end
