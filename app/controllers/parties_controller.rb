class PartiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  SORTS = %w[bench label number registered cohesion].freeze
  DIVIDED_POLLS = 5

  def index
    scope = apply_search(policy_scope(Party))
    @deputy_counts = Deputy.group(:party_id).count
    @candidate_counts = Candidate.group(:party_id).count
    @cohesion = DeputyMetrics.party_cohesion

    scope = scope.where(id: @deputy_counts.keys) if params[:bench] == "1"

    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "bench"
    parties = scope.to_a

    @parties = case @sort
               when "label"      then parties.sort_by(&:label)
               when "number"     then parties.sort_by { |p| [p.number || 9999, p.label] }
               when "registered" then parties.sort_by { |p| [p.registered_on || Date.new(2100, 1, 1), p.label] }
               when "cohesion"   then parties.sort_by { |p| pct = @cohesion.dig(p.id, :pct); [pct ? 0 : 1, -pct.to_i, p.label] }
               else                   parties.sort_by { |p| [-@deputy_counts[p.id].to_i, p.label] }
               end

    @total = @parties.size
  end

  def show
    @party = Party.find(params[:id])
    authorize @party

    @deputies = @party.deputies.order(:name)
    @candidate_count = @party.candidates.count
    @state_bench = @deputies.group_by(&:state_label).transform_values(&:size).sort_by { |state, count| [-count, state] }

    @cohesion = DeputyMetrics.party_cohesion[@party.id]
    @average_cohesion = DeputyMetrics.average_cohesion
    @alignment = DeputyMetrics.alignment
    @divided_polls = divided_polls
  end

  private

  # [[votação, { sim:, nao:, index: }]] em que a bancada mais se dividiu
  def divided_polls
    return [] unless @cohesion

    rows = @cohesion[:by_poll].reject { |_, row| row[:index] == 1 }
                              .sort_by { |poll_id, row| [row[:index], -poll_id] }
                              .first(DIVIDED_POLLS)
    polls = Poll.where(id: rows.map(&:first)).index_by(&:id)
    rows.filter_map { |poll_id, row| [polls[poll_id], row] if polls[poll_id] }
  end

  def apply_search(scope)
    return scope if params[:q].blank?

    term = "%#{params[:q].strip.upcase}%"
    scope.where(
      "upper(label) LIKE :t OR upper(name) LIKE :t OR upper(coalesce(former_labels, '')) LIKE :t",
      t: term
    )
  end
end
