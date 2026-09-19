class Deputy < ApplicationRecord
  belongs_to :party

  has_many :expenses, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :candidates, foreign_key: 'current_deputy_id', dependent: :destroy

  validates :name, :cpf, :state_label, presence: true
  validates :cpf, uniqueness: true, length: { is: 11 }, numericality: { only_integer: true }
end
