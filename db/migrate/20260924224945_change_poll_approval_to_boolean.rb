class ChangePollApprovalToBoolean < ActiveRecord::Migration[8.1]
  def change
    remove_column :polls, :approval, :string
    add_column :polls, :approval, :boolean
  end
end
