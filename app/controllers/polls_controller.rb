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
      approval: params[:approval].presence,
      government: params[:governo].presence
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

    @government = PollOrientation.where(label: "Governo", poll_id: @polls.map(&:id)).pluck(:poll_id, :orientation).to_h
    @years = Poll.where.not(date: nil).distinct.pluck(Arel.sql("EXTRACT(YEAR FROM date)::int")).sort.reverse
    @themes = Theme.all
  end

  def show
    @poll = Poll.find(params[:id])
    authorize @poll
    @breakdown = PollBreakdown.new(@poll)
  end

  private

  # Votações em que o resultado oficial coincidiu (venceu) ou não (perdeu) com a orientação do Governo
  def government_polls(value)
    comparison = value == "perdeu" ? "<>" : "="
    PollOrientation.joins(:poll)
                   .where(label: "Governo", orientation: %w[Sim Não])
                   .where.not(polls: { approval: nil })
                   .where("polls.description NOT LIKE 'Mantido o texto%'")
                   .where("(poll_orientations.orientation = 'Sim') #{comparison} polls.approval")
                   .select(:poll_id)
  end

  def apply(scope, filters)
    filters.reduce(scope) do |current, (key, value)|
      case key
      when :year     then current.where("EXTRACT(YEAR FROM polls.date) = ?", value.to_i)
      when :theme    then current.where(id: PollTheme.where(theme_id: value).select(:poll_id))
      when :approval then current.where(approval: value == "1")
      when :government then current.where(id: government_polls(value))
      else current
      end
    end
  end
end
