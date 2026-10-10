# Partido de um deputado a partir de uma data, montado do histórico da Câmara (ver PartyHistory).
# kind: "first" (primeiro registro na Câmara), "new_term" (outro partido ao voltar numa nova
# legislatura), "switch" (troca durante o mandato) ou "rename" (o partido mudou de nome ou se fundiu)
class PartyAffiliation < ApplicationRecord
  KINDS = %w[first new_term switch rename].freeze

  belongs_to :deputy
  belongs_to :party, optional: true

  validates :party_label, :legislature, :started_on, presence: true
  validates :kind, inclusion: { in: KINDS }

  # Mudança de partido por decisão do deputado (não conta mudança de nome nem fusão)
  def change? = kind.in?(%w[new_term switch])
end
