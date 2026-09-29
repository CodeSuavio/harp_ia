class Poll < ApplicationRecord
  belongs_to :bill

  has_many :votes, dependent: :destroy

  validates :date, :description, presence: true
end
