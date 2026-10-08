class PollsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 20

  def index
    base = policy_scope(Poll)
    base = base.where("polls.description ILIKE ?", "%#{Poll.sanitize_sql_like(params[:q].strip)}%") if params[:q].present?
    base = base.where(id: Vote.select(:poll_id)) unless params[:all] == "1"

    filters = {
      year:     params[:year].presence,
      theme:    params[:theme].presence,
      approval: params[:approval].presence
    }.compact

    scope = apply(base, filters)
    @theme_counts = PollTheme.where(poll_id: apply(base, filters.except(:theme)).select(:id)).group(:theme_id).count

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @polls = scope.includes(:themes, :bills)
                  .order(date: :desc, id: :desc)
                  .offset((@page - 1) * PER_PAGE)
                  .limit(PER_PAGE)
                  .to_a

    @tallies = Vote.where(poll_id: @polls.map(&:id)).group(:poll_id, :vote).count
    @years = Poll.where.not(date: nil).distinct.pluck(Arel.sql("EXTRACT(YEAR FROM date)::int")).sort.reverse
    @themes = Theme.all
  end

  def show
    @poll = Poll.find(params[:id])
    authorize @poll
    @breakdown = PollBreakdown.new(@poll)
  end

  private

  def apply(scope, filters)
    filters.reduce(scope) do |current, (key, value)|
      case key
      when :year     then current.where("EXTRACT(YEAR FROM polls.date) = ?", value.to_i)
      when :theme    then current.where(id: PollTheme.where(theme_id: value).select(:poll_id))
      when :approval then current.where(approval: value == "1")
      else current
      end
    end
  end
end
