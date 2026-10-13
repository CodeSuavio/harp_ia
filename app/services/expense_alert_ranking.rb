# Ranking dos deputados pelos alertas de gastos gravados (ExpenseAlert), com
# pontuação ponderada pela gravidade. Usado pela página de alertas
# (ExpenseAlertsController) e pela Harpia (ExpenseAlertRankingTool), para os
# dois mostrarem os mesmos números. Alertas não são prova de irregularidade.
class ExpenseAlertRanking
  # SUM(CASE severity WHEN 'high' THEN 5 ...), pesos em ExpenseAlert::WEIGHTS
  SCORE_SQL = Arel.sql(
    "SUM(CASE expense_alerts.severity " \
    "#{ExpenseAlert::WEIGHTS.map { |key, weight| "WHEN '#{key}' THEN #{weight}" }.join(' ')} ELSE 0 END)"
  )
  VALUE_SQL = Arel.sql("SUM(expense_alerts.value)")
  COUNT_SQL = ExpenseAlert::SEVERITY_ORDER.map do |severity|
    Arel.sql("COUNT(*) FILTER (WHERE expense_alerts.severity = '#{severity}')")
  end.freeze

  attr_reader :year

  # severity: gravidade mínima (low = todas, medium = média e alta, high = só alta)
  # order: score (pontuação dos alertas) ou share (% do gasto em notas com alerta)
  def initialize(year:, state: nil, party: nil, severity: "low", order: "score", scope: ExpenseAlert.all) # rubocop:disable Metrics/ParameterLists
    @year = year
    @state = state
    @party = party
    @severity = severity
    @order = order
    @scope = scope
  end

  # Quando os alertas do ano foram gravados (ExpenseAlerts::RefreshJob); nil = ano ainda não calculado
  def computed_at
    @scope.where(year: @year).maximum(:updated_at)
  end

  # Gasto de cada deputado no ano (DeputyMetrics.expenses)
  def expenses
    @expenses ||= DeputyMetrics.expenses(@year)
  end

  # [{ deputy_id:, score:, count:, value:, low:, medium:, high:, flagged:, share: }], na ordem escolhida
  def rows
    @rows ||= begin
      rows = with_shares(ranking)
      rows = rows.sort_by.with_index { |row, index| [-row[:share].to_f, index] } if @order == "share"
      rows
    end
  end

  private

  # Uma consulta agregada, da maior pontuação para a menor (desempate pelo valor sinalizado)
  def ranking
    alerts.group(:deputy_id)
          .order(Arel.sql("#{SCORE_SQL} DESC, #{VALUE_SQL} DESC NULLS LAST, MIN(deputies.name)"))
          .pluck(:deputy_id, SCORE_SQL, Arel.sql("COUNT(*)"), VALUE_SQL, *COUNT_SQL)
          .map do |deputy_id, score, count, value, *by_severity|
            { deputy_id: deputy_id, score: score, count: count, value: value,
              **ExpenseAlert::SEVERITY_ORDER.map(&:to_sym).zip(by_severity).to_h }
          end
  end

  # Alertas do recorte (ano, gravidade mínima, UF e partido)
  def alerts
    scope = @scope.where(year: @year).at_least(@severity).joins(:deputy)
    scope = scope.where(deputies: { state_label: @state }) if @state
    scope = scope.where(deputies: { party_id: @party.id }) if @party
    scope
  end

  # Acrescenta a cada linha o valor das notas com alerta e a fração do gasto do ano.
  # Usa as notas distintas (a mesma nota em dois alertas conta uma vez); alertas
  # sem notas (pico mensal, salto por tipo) não entram
  def with_shares(rows)
    note_ids = alerts.select(Arel.sql("UNNEST(expense_alerts.expense_ids)"))
    flagged = Expense.where(id: note_ids).group(:deputy_id).sum(:net_amount)

    rows.map do |row|
      value = flagged[row[:deputy_id]].to_d
      total = expenses.dig(row[:deputy_id], :total).to_d
      row.merge(flagged: value, share: total.positive? ? (value / total * 100).round(1) : nil)
    end
  end
end
