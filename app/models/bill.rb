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

  # Projetos em que o deputado é autor principal (deputy_id) ou coautor (bill_authors)
  scope :authored_by, ->(deputies) { where(deputy_id: deputies).or(where(id: BillAuthor.where(deputy_id: deputies).select(:bill_id))) }

  validates :bill_number, :year, presence: true
  validates :year, numericality: { only_integer: true, greater_than: 1900 }
  validates :bill_number, uniqueness: { scope: :year, message: "já existe para o ano especificado" }

  # { deputy_id => projetos de autoria ou coautoria }, sem contar duas vezes o mesmo projeto
  def self.count_by_author(deputies)
    pairs = [
      unscoped.where(deputy_id: deputies).select(:id, :deputy_id).to_sql,
      BillAuthor.where(deputy_id: deputies).select(:bill_id, :deputy_id).to_sql
    ].join(" UNION ")
    unscoped.from("(#{pairs}) AS bills").group(:deputy_id).count
  end
end
