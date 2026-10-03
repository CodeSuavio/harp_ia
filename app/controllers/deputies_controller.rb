class DeputiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  PER_PAGE = 24
  SORTS = {
    "name"  => { name: :asc },
    "state" => { state_label: :asc, name: :asc }
  }.freeze

  def index
    base = apply_search(policy_scope(Deputy))

    filters = {
      state_label:      params[:state].presence,
      party_id:         params[:party].presence,
      electoral_status: params[:electoral_status].presence
    }.compact

    scope = apply(base, filters)

    @state_counts  = apply(base, filters.except(:state_label)).group(:state_label).count
    @party_counts  = apply(base, filters.except(:party_id)).group(:party_id).count
    @status_counts = apply(base, filters.except(:electoral_status)).group(:electoral_status).count

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "name"
    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages

    @deputies = scope.includes(:party)
                     .order(SORTS[@sort])
                     .offset((@page - 1) * PER_PAGE)
                     .limit(PER_PAGE)

    @states = Deputy.distinct.pluck(:state_label).compact.sort
    @statuses = Deputy.distinct.pluck(:electoral_status).compact.sort
    @parties = Party.order(:label)
  end

  def show
    @deputy = Deputy.find(params[:id])
    authorize @deputy
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
      scope.where("deputies.name ILIKE :l OR deputies.party_id IN (:ids)", l: like, ids: party_ids)
    else
      scope.where("deputies.name ILIKE :l", l: like)
    end
  end
end
