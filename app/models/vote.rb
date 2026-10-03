class Vote < ApplicationRecord
  DECISIVE = %w[Sim Não].freeze # votos que expressam posição (usados no alinhamento partidário)

  belongs_to :poll
  belongs_to :deputy

  validates :vote, presence: true
  validates :vote, inclusion: { in: ['Sim', 'Não', 'Abstenção', 'Obstrução', 'Artigo 17'] }
  validates :deputy_id, uniqueness: { scope: :poll_id, message: "só pode registrar um voto por votação" }
end
