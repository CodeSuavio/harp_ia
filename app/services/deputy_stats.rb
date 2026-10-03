# Indicadores calculados de um deputado: gastos, comparações com a média
# e comportamento nas votações. Para indicadores de todos os deputados de uma
# vez (listagem, rankings), ver DeputyMetrics.
class DeputyStats
  # A partir de quanto um fornecedor concentra "demais" os gastos do ano.
  # Com 50%, o alerta marca ~15% dos deputados (dados de 2025); com 30% marcaria
  # a maioria, porque aluguel de escritório já concentra boa parte da cota.
  SUPPLIER_CONCENTRATION_ALERT = 50
  # Tipos concentrados por natureza (companhia aérea, ramal da Câmara): fora do cálculo
  CONCENTRATION_IGNORED_TYPES = ["PASSAGEM AÉREA%", "TELEFONIA"].freeze
  # A partir de quantas vezes a média um tipo de despesa ganha destaque
  TYPE_ABOVE_AVERAGE = 1.5

  def initialize(deputy)
    @deputy = deputy
  end

  # ----- GASTOS -----

  def total_expenses(year: nil)
    scope = @deputy.expenses
    scope = scope.where(year: year) if year
    scope.sum(:net_amount)
  end

  # Gasto médio por mês com despesa (não penaliza quem assumiu no meio do ano)
  def monthly_average(year:)
    DeputyMetrics.expenses(year).dig(@deputy.id, :monthly) || 0
  end

  # Média do gasto mensal dos deputados do mesmo estado e do mesmo partido
  # (considerando apenas quem tem despesas no ano)
  def expense_benchmarks(year:)
    {
      state: average_monthly(Deputy.where(state_label: @deputy.state_label), year),
      party: average_monthly(Deputy.where(party_id: @deputy.party_id), year)
    }
  end

  # Variação do gasto em relação ao mesmo período (meses) do ano anterior
  def year_over_year(year:)
    last_month = Expense.where(year: year).maximum(:month)
    previous = @deputy.expenses.where(year: year - 1, month: ..last_month.to_i)
    return unless last_month && previous.exists?

    before = previous.sum(:net_amount)
    now = total_expenses(year: year)
    { previous: before, pct: before.zero? ? nil : ((now - before) / before * 100).round, last_month: last_month }
  end

  # Gasto por tipo comparado com a média da Câmara no mesmo tipo
  # (média = total do tipo / deputados com despesa no ano)
  def expenses_by_type(year:)
    own = @deputy.expenses.where(year: year).group(:expense_type).sum(:net_amount)
    deputies = DeputyMetrics.expenses(year).size
    averages = Expense.where(year: year, expense_type: own.keys).group(:expense_type).sum(:net_amount)

    own.map do |type, value|
      average = deputies.zero? ? 0 : averages[type].to_f / deputies
      { type: type, value: value, average: average, ratio: average.zero? ? nil : (value.to_f / average).round(1) }
    end.sort_by { |row| -row[:value] }
  end

  # Fatia do gasto do ano que foi para o principal fornecedor
  # (sem passagens aéreas e telefonia, ver CONCENTRATION_IGNORED_TYPES)
  def supplier_concentration(year:)
    scope = @deputy.expenses.where(year: year)
    CONCENTRATION_IGNORED_TYPES.each { |type| scope = scope.where.not("expense_type LIKE ?", type) }
    total = scope.sum(:net_amount)
    scope = scope.where.not(supplier: [nil, ""])
    supplier, value = scope.group(:supplier).order(Arel.sql("SUM(net_amount) DESC")).limit(1).sum(:net_amount).first
    return unless supplier && total.positive?

    pct = (value / total * 100).round
    { supplier: supplier, value: value, pct: pct, alert: pct >= SUPPLIER_CONCENTRATION_ALERT }
  end

  # ----- VOTAÇÕES -----

  # Denominador: votações com votos registrados entre o primeiro e o último voto do deputado
  def vote_participation
    from, to = @deputy.votes.joins(:poll).pick(Arel.sql("MIN(polls.date)"), Arel.sql("MAX(polls.date)"))
    voted = @deputy.votes.count
    total = from ? Poll.where(id: Vote.select(:poll_id), date: from..to).count : 0
    DeputyMetrics.participation_row(voted, total, from, to)
  end

  # Em quantas votações o deputado acompanhou a maioria do próprio partido
  # (só contam votações em que ele votou Sim/Não e o partido não empatou)
  def party_alignment
    decisive = decisive_votes_with_majority
    aligned = decisive.count { |_, vote, majority| majority == vote }
    {
      aligned: aligned,
      total: decisive.size,
      against: decisive.size - aligned,
      pct: DeputyMetrics.percentage(aligned, decisive.size)
    }
  end

  # Votações em que o deputado votou contra a maioria do partido
  def against_party_poll_ids
    decisive_votes_with_majority.reject { |_, vote, majority| majority == vote }.map(&:first)
  end

  # Voto majoritário do partido (excluindo o próprio deputado) em cada votação
  def party_majorities(poll_ids = nil)
    scope = Vote.joins(:deputy)
                .where(deputies: { party_id: @deputy.party_id }, vote: Vote::DECISIVE)
                .where.not(deputy_id: @deputy.id)
    scope = scope.where(poll_id: poll_ids) if poll_ids

    scope.group(:poll_id, :vote).count
         .group_by { |(poll_id, _), _| poll_id }
         .transform_values do |rows|
           sim = rows.find { |(_, vote), _| vote == "Sim" }&.last.to_i
           nao = rows.find { |(_, vote), _| vote == "Não" }&.last.to_i
           DeputyMetrics.majority_of(sim, nao)
         end
  end

  private

  # [[poll_id, voto, maioria do partido]] para os votos Sim/Não em que o partido não empatou
  def decisive_votes_with_majority
    majorities = party_majorities
    @deputy.votes.where(vote: Vote::DECISIVE).pluck(:poll_id, :vote)
           .filter_map { |poll_id, vote| [poll_id, vote, majorities[poll_id]] if majorities[poll_id] }
  end

  def average_monthly(deputies, year)
    data = DeputyMetrics.expenses(year)
    values = deputies.pluck(:id).filter_map { |id| data.dig(id, :monthly) }
    return 0 if values.empty?

    values.sum / values.size
  end
end
