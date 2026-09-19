class AddDetailsToPolls < ActiveRecord::Migration[8.1]
  def change
    add_column :polls, :date, :datetime
    add_column :polls, :description, :text
    add_column :polls, :approval, :string
    add_column :polls, :label_comission, :string
  end
end
