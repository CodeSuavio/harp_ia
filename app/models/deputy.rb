class Deputy < ApplicationRecord
  belongs_to :party

  has_many :expenses, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :candidates, foreign_key: :current_deputy_id, primary_key: :json_id, dependent: :destroy, inverse_of: :current_deputy #id recebido na coluna json_id

  has_one_attached :photo

  validates :name, :cpf, :state_label, presence: true
  validates :cpf, uniqueness: true, length: { is: 11 }, numericality: { only_integer: true }
  validates :json_id, uniqueness: true, presence: true
end
