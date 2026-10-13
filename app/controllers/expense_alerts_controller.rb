# Ranking dos deputados pelos alertas de gastos gravados (ExpenseAlert), com
# pontuação ponderada pela gravidade (ExpenseAlertRanking, o mesmo da Harpia).
# Alertas não são prova de irregularidade.
class ExpenseAlertsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  PER_PAGE = 24
  SEVERITY_LABELS = { "low" => "Todas", "medium" => "Média e alta", "high" => "Só alta" }.freeze
  ORDERS = { "score" => "Pontuação dos alertas", "share" => "% do gasto em notas com alerta" }.freeze

  def index
    authorize ExpenseAlert
    read_filters
    ranking = ExpenseAlertRanking.new(year: @year, state: @state, party: @party, severity: @severity, order: @order,
                                      scope: policy_scope(ExpenseAlert))
    # Os alertas são gravados por ExpenseAlerts::RefreshJob; nil = ano ainda não calculado
    @computed_at = ranking.computed_at
    @expenses = ranking.expenses
    @page_rows = with_deputies(page_of(ranking.rows))

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
    @order = ORDERS.key?(params[:order]) ? params[:order] : "score"
  end

  def page_of(rows)
    @total = rows.size
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    rows.slice((@page - 1) * PER_PAGE, PER_PAGE) || []
  end

  # Deputados da página numa consulta só (com partido e foto)
  def with_deputies(rows)
    deputies = Deputy.includes(:party).with_attached_photo.where(id: rows.pluck(:deputy_id)).index_by(&:id)
    rows.filter_map { |row| row.merge(deputy: deputies[row[:deputy_id]]) if deputies[row[:deputy_id]] }
  end
end
