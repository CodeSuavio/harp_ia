class Bill < ApplicationRecord
  belongs_to :deputy
  belongs_to :party

  has_many :polls
  has_many :users
end
