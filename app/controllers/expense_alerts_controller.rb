# Ranking dos deputados pelos alertas de gastos gravados (ExpenseAlert), com
# pontuação ponderada pela gravidade. Alertas não são prova de irregularidade.
class ExpenseAlertsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  PER_PAGE = 24
  SEVERITY_LABELS = { "low" => "Todas", "medium" => "Média e alta", "high" => "Só alta" }.freeze

  # SUM(CASE severity WHEN 'high' THEN 5 ...), pesos em ExpenseAlert::WEIGHTS
  SCORE_SQL = Arel.sql(
    "SUM(CASE expense_alerts.severity " \
    "#{ExpenseAlert::WEIGHTS.map { |key, weight| "WHEN '#{key}' THEN #{weight}" }.join(' ')} ELSE 0 END)"
  )
  VALUE_SQL = Arel.sql("SUM(expense_alerts.value)")
  COUNT_SQL = ExpenseAlert.severities.keys.map do |severity|
    Arel.sql("COUNT(*) FILTER (WHERE expense_alerts.severity = '#{severity}')")
  end.freeze

  def index
    authorize ExpenseAlert
    read_filters

    rows = ranking
    @total = rows.size
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @page_rows = with_deputies(rows.slice((@page - 1) * PER_PAGE, PER_PAGE) || [])

    @expenses = DeputyMetrics.expenses(@year)
    @note_counts = Expense.where(year: @year, deputy_id: @page_rows.pluck(:deputy_id)).group(:deputy_id).count
    @states = Deputy.distinct.pluck(:state_label).compact.sort
    @parties = Party.where(id: Deputy.select(:party_id)).order(:label)
  end

  private

  def read_filters
    @years = Expense.distinct.order(year: :desc).pluck(:year)
    @year = @years.include?(params[:year].to_i) ? params[:year].to_i : DeputyMetrics.reference_year
    @state = params[:state].presence
    @party = Party.find_by(id: params[:party]) if params[:party].present?
    @severity = SEVERITY_LABELS.key?(params[:severity]) ? params[:severity] : "low"
  end

  # Deputados da página numa consulta só (com partido e foto)
  def with_deputies(rows)
    deputies = Deputy.includes(:party).with_attached_photo.where(id: rows.pluck(:deputy_id)).index_by(&:id)
    rows.filter_map { |row| row.merge(deputy: deputies[row[:deputy_id]]) if deputies[row[:deputy_id]] }
  end

  # Uma consulta agregada: [{ deputy_id:, score:, count:, value:, low:, medium:, high: }],
  # da maior pontuação para a menor (desempate pelo valor sinalizado)
  def ranking
    scope = policy_scope(ExpenseAlert).where(year: @year).at_least(@severity).joins(:deputy)
    scope = scope.where(deputies: { state_label: @state }) if @state
    scope = scope.where(deputies: { party_id: @party.id }) if @party

    scope.group(:deputy_id)
         .order(Arel.sql("#{SCORE_SQL} DESC, #{VALUE_SQL} DESC NULLS LAST, MIN(deputies.name)"))
         .pluck(:deputy_id, SCORE_SQL, Arel.sql("COUNT(*)"), VALUE_SQL, *COUNT_SQL)
         .map do |deputy_id, score, count, value, *by_severity|
           { deputy_id: deputy_id, score: score, count: count, value: value,
             **ExpenseAlert.severities.keys.map(&:to_sym).zip(by_severity).to_h }
         end
  end
end
