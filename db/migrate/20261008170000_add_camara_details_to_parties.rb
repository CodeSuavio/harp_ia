class AddCamaraDetailsToParties < ActiveRecord::Migration[8.1]
  def change
    add_column :parties, :logo_url, :string
    add_column :parties, :leader_json_id, :bigint
    add_column :parties, :leader_name, :string
    add_column :parties, :seats_at_start, :integer
  end
end
