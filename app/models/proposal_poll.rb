# Votação ligada a uma proposta: `favorable_vote` é o voto (Sim/Não) que cumpre a proposta
class ProposalPoll < ApplicationRecord
  belongs_to :proposal
  belongs_to :poll

  validates :favorable_vote, inclusion: { in: Vote::DECISIVE }
  validates :poll_id, uniqueness: { scope: :proposal_id }
end
