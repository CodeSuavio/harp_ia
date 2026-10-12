# Alertas de ExpenseAnomalies gravados por deputado e ano (ExpenseAlerts::RefreshJob),
# para o ranking comparar a Câmara toda sem recalcular as regras a cada visita.
# A aba Gastos do perfil continua calculando os alertas na hora.
class ExpenseAlert < ApplicationRecord
  # Peso de cada gravidade na pontuação do ranking
  WEIGHTS = { "high" => 5, "medium" => 2, "low" => 1 }.freeze

  belongs_to :deputy

  # Da menor para a maior: at_least depende desta ordem, não da declaração do enum
  SEVERITY_ORDER = %w[low medium high].freeze

  enum :severity, SEVERITY_ORDER.index_by(&:itself), validate: true

  validates :year, :kind, presence: true

  # Gravidade igual ou acima da informada ("medium" → medium e high); valor desconhecido = todas
  scope :at_least, ->(severity) { where(severity: SEVERITY_ORDER.drop(SEVERITY_ORDER.index(severity.to_s).to_i)) }

  # Linha de ExpenseAnomalies#for_year → atributos (o resto vai para details)
  def self.attributes_from(row)
    { kind: row[:kind].to_s, severity: row[:severity].to_s, value: row[:value], expense_ids: row[:expense_ids].to_a,
      details: row.except(:kind, :severity, :value, :expense_ids) }
  end
end
