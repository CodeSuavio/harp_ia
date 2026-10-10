class AddPageContextToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :page_context, :text
  end
end
