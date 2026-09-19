class AddDetailsToBills < ActiveRecord::Migration[8.1]
  def change
    add_column :bills, :bill_number, :string
    add_column :bills, :year, :integer
    add_column :bills, :summary, :text
    add_column :bills, :keywords, :string
    add_column :bills, :submission_date, :date
    add_column :bills, :url, :string
  end
end
