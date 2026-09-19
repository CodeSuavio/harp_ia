class Party < ApplicationRecord
  has_many :deputies
  has_many :candidates
  has_many :bills
  has_many :users
end
