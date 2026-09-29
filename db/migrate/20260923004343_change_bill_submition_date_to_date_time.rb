class ChangeBillSubmitionDateToDateTime < ActiveRecord::Migration[8.1]
  def up
    change_column :bills, :submission_date, :datetime
  end

  def down
    change_column :bills, :submission_date, :date
  end
end
