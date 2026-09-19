class AddDetailsToVotes < ActiveRecord::Migration[8.1]
  def change
    add_column :votes, :vote, :string
  end
end
