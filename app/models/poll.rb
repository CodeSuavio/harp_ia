class Poll < ApplicationRecord
  belongs_to :bill, optional: true

  has_many :votes, dependent: :destroy

  validates :date, :description, presence: true
end
