class CandidatesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 24
  SORTS = {
    "name"   => { ballot_name: :asc },
    "state"  => { state_label: :asc, ballot_name: :asc },
    "number" => { number: :asc }
  }.freeze

  def index
    base = apply_search(policy_scope(Candidate))

    filters = {
      state_label: params[:state].presence,
      party_id:    params[:party].presence,
      gender:      params[:gender].presence
    }.compact

    scope = apply(base, filters)

    @state_counts  = apply(base, filters.except(:state_label)).group(:state_label).count
    @party_counts  = apply(base, filters.except(:party_id)).group(:party_id).count
    @gender_counts = apply(base, filters.except(:gender)).group(:gender).count

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "name"
    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @candidates = scope.includes(:party)
                       .order(SORTS[@sort])
                       .offset((@page - 1) * PER_PAGE)
                       .limit(PER_PAGE)

    @states = Candidate.distinct.pluck(:state_label).compact.sort
    @parties = Party.order(:label)
  end

  def show
    @candidate = Candidate.find(params[:id])
    authorize @candidate
  end

  private

  def apply(scope, filters)
    filters.reduce(scope) { |s, (column, value)| s.where(column => value) }
  end

  def apply_search(scope)
    return scope if params[:q].blank?

    term = params[:q].strip
    like = "%#{term}%"
    party_ids = Party.where(
      "upper(label) = :t OR upper(coalesce(former_labels, '')) LIKE :lt",
      t: term.upcase, lt: "%#{term.upcase}%"
    ).pluck(:id)

    if party_ids.any?
      scope.where(
        "candidates.ballot_name ILIKE :l OR candidates.name ILIKE :l OR candidates.party_id IN (:ids)",
        l: like, ids: party_ids
      )
    else
      scope.where("candidates.ballot_name ILIKE :l OR candidates.name ILIKE :l", l: like)
    end
  end
end
