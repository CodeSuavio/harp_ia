class Bill < ApplicationRecord
  belongs_to :deputy
  belongs_to :party

  has_many :polls, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :bill_number, :year, presence: true
  validates :year, numericality: { only_integer: true, greater_than: 1900 }
  validates :bill_number, uniqueness: { scope: :year, message: "já existe para o ano especificado" }
end
