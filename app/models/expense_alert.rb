# Alertas de ExpenseAnomalies gravados por deputado e ano (ExpenseAlerts::RefreshJob),
# para o ranking comparar a Câmara toda sem recalcular as regras a cada visita.
# A aba Gastos do perfil continua calculando os alertas na hora.
class ExpenseAlert < ApplicationRecord
  # Peso de cada gravidade na pontuação do ranking
  WEIGHTS = { "high" => 5, "medium" => 2, "low" => 1 }.freeze

  belongs_to :deputy

  enum :severity, { low: "low", medium: "medium", high: "high" }, validate: true

  validates :year, :kind, presence: true

  # Gravidade igual ou acima da informada ("medium" → medium e high)
  scope :at_least, ->(severity) { where(severity: severities.keys.drop(severities.keys.index(severity.to_s).to_i)) }

  # Linha de ExpenseAnomalies#for_year → atributos (o resto vai para details)
  def self.attributes_from(row)
    { kind: row[:kind].to_s, severity: row[:severity].to_s, value: row[:value], expense_ids: row[:expense_ids].to_a,
      details: row.except(:kind, :severity, :value, :expense_ids) }
  end
end
