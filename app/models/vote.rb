class Vote < ApplicationRecord
  belongs_to :poll
  belongs_to :deputy

  validates :vote, presence: true
  validates :vote, inclusion: { in: %w[Sim Não Abstenção Obstrução] }
  validates :deputy_id, uniqueness: { scope: :poll_id, message: "só pode registrar um voto por votação" }
end
