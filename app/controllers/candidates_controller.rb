class CandidatesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 24

  def index
    scope = policy_scope(Candidate).includes(:party)
    scope = scope.where(state_label: params[:state]) if params[:state].present?
    scope = scope.where(party_id: params[:party]) if params[:party].present?

    if params[:q].present?
      term = "%#{params[:q].strip}%"
      scope = scope.where("candidates.ballot_name ILIKE :t OR candidates.name ILIKE :t", t: term)
    end

    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @candidates = scope.order(:ballot_name)
                       .offset((@page - 1) * PER_PAGE)
                       .limit(PER_PAGE)

    @states = Candidate.distinct.pluck(:state_label).compact.sort
    @parties = Party.order(:label)
  end

  def show
    @candidate = Candidate.find(params[:id])
    authorize @candidate
  end
end
