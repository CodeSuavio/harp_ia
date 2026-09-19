class Poll < ApplicationRecord
  belongs_to :bill

  has_many :votes

  validates :date, :description, presence: true
end
