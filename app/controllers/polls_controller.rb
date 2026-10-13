class PollsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  PER_PAGE = 20

  def index
    # Mesma busca da Harpia (PollListTool)
    search = PollSearch.new(policy_scope(Poll), query: params[:q], all: params[:all] == "1", year: params[:year],
                                                theme: params[:theme], approval: params[:approval],
                                                government: params[:governo])
    scope = search.results
    @theme_counts = PollTheme.where(poll_id: search.results(except: :theme).select(:id)).group(:theme_id).count

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @polls = scope.includes(:themes, :bills)
                  .order(PollSearch::ORDER)
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
end
