# Orientação de voto que a liderança de um partido, federação ou bloco deu
# numa votação (API da Câmara: /votacoes/{id}/orientacoes).
class PollOrientation < ApplicationRecord
  # Orientações que indicam um lado; as demais são "Liberado" e "Obstrução"
  DECISIVE = %w[Sim Não].freeze
  # Federações aparecem como "Fdr PT-PCdoB-PV"; blocos ("Bl ...") não dizem quais partidos reúnem
  FEDERATION_PREFIX = "Fdr ".freeze

  belongs_to :poll
  belongs_to :party, optional: true

  validates :label, :orientation, presence: true

  scope :federations, -> { where("poll_orientations.label LIKE ?", "#{FEDERATION_PREFIX}%") }

  # Siglas (em maiúsculas) dos partidos de uma federação
  def self.federation_members(label)
    label.to_s.delete_prefix(FEDERATION_PREFIX).split("-").map { |sigla| sigla.strip.upcase }
  end
end
