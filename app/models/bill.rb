class Bill < ApplicationRecord
  belongs_to :deputy, optional: true
  belongs_to :party, optional: true

  has_many :polls, dependent: :destroy
  has_many :bill_themes, dependent: :delete_all
  has_many :themes, through: :bill_themes
  has_many :bill_authors, dependent: :delete_all
  has_many :authors, through: :bill_authors, source: :deputy
  has_many :poll_bills, dependent: :delete_all
  has_many :votings, through: :poll_bills, source: :poll

  validates :bill_number, :year, presence: true
  validates :year, numericality: { only_integer: true, greater_than: 1900 }
  validates :bill_number, uniqueness: { scope: :year, message: "já existe para o ano especificado" }
end
