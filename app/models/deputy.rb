class Deputy < ApplicationRecord
  belongs_to :party

  has_many :expenses
  has_many :bills
  has_many :votes
  has_many :users

  # Relação indicando que o deputado atual pode estar ligado a um registo de candidato
  has_many :candidates, foreign_key: 'current_deputy_id'
end
