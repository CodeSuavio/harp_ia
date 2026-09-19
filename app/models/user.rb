class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :candidate, optional: true
  belongs_to :deputy, optional: true
  belongs_to :party, optional: true
  belongs_to :bill, optional: true

  validates :first_name, :last_name, presence: true
end
