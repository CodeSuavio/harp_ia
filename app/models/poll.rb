class Poll < ApplicationRecord
  belongs_to :bill

  has_many :votes
end
