class Deputy < ApplicationRecord
  belongs_to :party

  has_many :expenses
  has_many :bills
  has_many :votes
  has_many :users
  has_many :candidates, foreign_key: 'current_deputy_id'

  validates :name, :cpf, :state_label, presence: true
  validates :cpf, uniqueness: true, length: { is: 11 }, numericality: { only_integer: true }
end
