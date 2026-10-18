# Lista e indicadores da página de gastos de campanha: quanto cada candidato a deputado
# federal gastou em 2026, quantos votos teve e quanto custou cada voto.
#
# Custo por voto = despesas contratadas ÷ votos nominais do 1º turno. Só entra quem
# declarou gasto e teve voto; a mediana é usada no lugar da média porque poucos
# candidatos com pouquíssimos votos distorcem a média.
class CampaignFinanceRanking
  COST_PER_VOTE = "campaign_finances.expenses / NULLIF(campaign_finances.votes, 0)".freeze

  SORTS = {
    "expenses" => "campaign_finances.expenses DESC NULLS LAST",
    "votes" => "campaign_finances.votes DESC NULLS LAST",
    "cost_desc" => "#{COST_PER_VOTE} DESC NULLS LAST",
    "cost_asc" => "#{COST_PER_VOTE} ASC NULLS LAST"
  }.freeze

  attr_reader :scope

  def initialize(state: nil, party: nil, result: nil, query: nil, scope: CampaignFinance.all)
    @scope = scope.joins(:candidate)
    @scope = @scope.where(candidates: { id: Candidate.search(query).select(:id) }) if query.present?
    @scope = @scope.where(candidates: { state_label: state }) if state.present?
    @scope = @scope.where(candidates: { party_id: party.id }) if party
    @scope = @scope.where(result: CampaignFinance::RESULT_GROUPS[result]) if CampaignFinance::RESULT_GROUPS.key?(result)
  end

  def ordered(sort)
    order = SORTS.fetch(sort, SORTS["expenses"])
    # Custo por voto só faz sentido para quem gastou e teve voto
    base = sort.to_s.start_with?("cost") ? scope.with_spending.with_votes : scope
    base.order(Arel.sql("#{order}, campaign_finances.id"))
  end

  # Totais do recorte para a faixa de indicadores no topo da página
  def summary
    @summary ||= begin
      row = scope.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COALESCE(SUM(campaign_finances.expenses), 0)"),
        Arel.sql("COALESCE(SUM(campaign_finances.votes), 0)"),
        Arel.sql("COALESCE(SUM(campaign_finances.public_funds), 0)"),
        Arel.sql("COALESCE(SUM(campaign_finances.revenues), 0)"),
        Arel.sql("COUNT(*) FILTER (WHERE campaign_finances.result IN (#{quoted(CampaignFinance::ELECTED_RESULTS)}))")
      )
      count, expenses, votes, public_funds, revenues, elected = row
      {
        count: count, expenses: expenses.to_f, votes: votes.to_i, elected: elected,
        cost_per_vote: (expenses.to_f / votes if votes.to_i.positive?),
        public_share: (public_funds.to_f / revenues.to_f * 100).round(1).then { |v| v if revenues.to_f.positive? },
        median_cost_elected: median_cost(scope.elected),
        median_cost_others: median_cost(scope.where.not(result: CampaignFinance::ELECTED_RESULTS))
      }
    end
  end

  # Quem gasta mais se elege mais? Candidatos com gasto divididos em quatro faixas
  # do mesmo tamanho, do menor para o maior gasto.
  def spending_quartiles
    ranked = scope.with_spending.select(
      "campaign_finances.*",
      "NTILE(4) OVER (ORDER BY campaign_finances.expenses) AS quartile"
    )
    CampaignFinance.from(ranked, :campaign_finances)
                   .group(:quartile).order(:quartile)
                   .pluck(
                     :quartile,
                     Arel.sql("COUNT(*)"),
                     Arel.sql("MIN(expenses)"),
                     Arel.sql("MAX(expenses)"),
                     Arel.sql("COUNT(*) FILTER (WHERE result IN (#{quoted(CampaignFinance::ELECTED_RESULTS)}))"),
                     Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY #{COST_PER_VOTE}) FILTER (WHERE votes > 0)")
                   ).map do |quartile, count, min, max, elected, median|
      { quartile: quartile, count: count, min: min.to_f, max: max.to_f, elected: elected,
        elected_share: (elected * 100.0 / count).round(1), median_cost: median&.to_f }
    end
  end

  # Mediana do custo por voto e total de votos nominais por UF (para comparar cada
  # candidato com os concorrentes do mesmo estado, sem os outros filtros)
  def self.state_benchmarks
    CampaignFinance.joins(:candidate).group("candidates.state_label").pluck(
      Arel.sql("candidates.state_label"),
      Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY #{COST_PER_VOTE}) FILTER (WHERE campaign_finances.votes > 0 AND campaign_finances.expenses > 0)"),
      Arel.sql("COALESCE(SUM(campaign_finances.votes), 0)")
    ).to_h { |state, median, votes| [state, { median_cost: median&.to_f, votes: votes.to_i }] }
  end

  private

  def median_cost(relation)
    relation.with_spending.with_votes
            .pick(Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY #{COST_PER_VOTE})"))&.to_f
  end

  def quoted(values)
    values.map { |v| CampaignFinance.connection.quote(v) }.join(", ")
  end
end
