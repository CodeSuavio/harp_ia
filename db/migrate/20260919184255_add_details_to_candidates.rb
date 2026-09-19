class AddDetailsToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :candidates, :electoral_id, :string
    add_column :candidates, :name, :string
    add_column :candidates, :ballot_name, :string
    add_column :candidates, :number, :integer
    add_column :candidates, :state_label, :string
    add_column :candidates, :candidacy_status, :string
    add_column :candidates, :running_for_reelection, :boolean
    add_column :candidates, :gender, :string
    add_column :candidates, :race_color, :string
    add_column :candidates, :education_level, :string
    add_column :candidates, :occupation, :string
    add_column :candidates, :photo_file, :string
  end
end
