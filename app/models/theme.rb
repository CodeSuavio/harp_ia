class Theme < ApplicationRecord
  has_many :bill_themes, dependent: :delete_all
  has_many :poll_themes, dependent: :delete_all
  has_many :bills, through: :bill_themes
  has_many :polls, through: :poll_themes
  has_many :proposals, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  default_scope { order(:position, :name) }

  def keyword_list
    keywords.to_s.split(",").map(&:strip).compact_blank
  end
end
