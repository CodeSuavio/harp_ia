class Poll < ApplicationRecord
  belongs_to :bill, optional: true

  has_many :votes, dependent: :destroy
  has_many :poll_themes, dependent: :delete_all
  has_many :themes, through: :poll_themes
  has_many :poll_bills, dependent: :delete_all
  has_many :bills, through: :poll_bills
  has_many :proposal_polls, dependent: :delete_all
  has_many :poll_orientations, dependent: :delete_all

  validates :date, :description, presence: true
end
