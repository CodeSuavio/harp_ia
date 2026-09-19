class Party < ApplicationRecord
  has_many :deputies, dependent: :destroy
  has_many :candidates, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :users, dependent: :destroy
  
  validates :name, :label, presence: true
  validates :label, uniqueness: { case_sensitive: false }
end
