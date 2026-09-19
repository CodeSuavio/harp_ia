class AddDetailsToDeputies < ActiveRecord::Migration[8.1]
  def change
    add_column :deputies, :name, :string
    add_column :deputies, :cpf, :string
    add_column :deputies, :state_label, :string
    add_column :deputies, :photo_url, :string
    add_column :deputies, :email, :string
    add_column :deputies, :status, :string
    add_column :deputies, :electoral_status, :string
    add_column :deputies, :date_of_birth, :date
    add_column :deputies, :city_of_birth, :string
    add_column :deputies, :state_of_birth, :string
    add_column :deputies, :education_level, :string
    add_column :deputies, :social_media, :string
    add_column :deputies, :office_building, :string
    add_column :deputies, :office_room, :string
    add_column :deputies, :office_phone, :string
  end
end
