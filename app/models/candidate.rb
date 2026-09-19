class Candidate < ApplicationRecord
  belongs_to :party
  belongs_to :current_deputy, class_name: 'Deputy', optional: true

  has_many :users

  validates :name, :ballot_name, :number, :electoral_id, presence: true
  validates :electoral_id, uniqueness: true
  validates :number, numericality: { only_integer: true }
end
