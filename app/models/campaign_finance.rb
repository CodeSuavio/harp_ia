# Votos e prestação de contas da campanha de 2026 de um candidato a deputado federal,
# agregados dos dados abertos do TSE (ver CampaignFinanceImporter).
class CampaignFinance < ApplicationRecord
  belongs_to :candidate

  # Situação no 1º turno (DS_SIT_TOT_TURNO do TSE)
  ELECTED_RESULTS = ["ELEITO POR QP", "ELEITO POR MÉDIA", "ELEITO"].freeze
  RESULT_GROUPS = {
    "elected" => ELECTED_RESULTS,
    "substitute" => ["SUPLENTE"],
    "not_elected" => ["NÃO ELEITO"]
  }.freeze

  scope :with_spending, -> { where("campaign_finances.expenses > 0") }
  scope :with_votes, -> { where("campaign_finances.votes > 0") }
  scope :elected, -> { where(result: ELECTED_RESULTS) }

  def elected?
    ELECTED_RESULTS.include?(result)
  end

  # Gasto (despesas contratadas) dividido pelos votos nominais
  def cost_per_vote
    expenses.to_f / votes if votes.to_i.positive? && expenses.to_f.positive?
  end

  # Parte da receita vinda do Fundo Eleitoral (FEFC) e do Fundo Partidário
  def public_share
    percent(public_funds, revenues)
  end

  def own_share
    percent(own_funds, revenues)
  end

  private

  def percent(part, whole)
    (part.to_f / whole * 100).round(1) if whole.to_f.positive?
  end
end
