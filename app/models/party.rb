class Party < ApplicationRecord
  has_many :deputies
  has_many :candidates
  has_many :bills
  has_many :users
  validates :name, :label, presence: true
  validates :label, uniqueness: { case_sensitive: false }
end
