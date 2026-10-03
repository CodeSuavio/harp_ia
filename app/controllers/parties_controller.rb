class PartiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  SORTS = %w[bench label number registered].freeze

  def index
    scope = apply_search(policy_scope(Party))
    @deputy_counts = Deputy.group(:party_id).count
    @candidate_counts = Candidate.group(:party_id).count

    scope = scope.where(id: @deputy_counts.keys) if params[:bench] == "1"

    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "bench"
    parties = scope.to_a

    @parties = case @sort
               when "label"      then parties.sort_by(&:label)
               when "number"     then parties.sort_by { |p| [p.number || 9999, p.label] }
               when "registered" then parties.sort_by { |p| [p.registered_on || Date.new(2100, 1, 1), p.label] }
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
  end

  private

  def apply_search(scope)
    return scope if params[:q].blank?

    term = "%#{params[:q].strip.upcase}%"
    scope.where(
      "upper(label) LIKE :t OR upper(name) LIKE :t OR upper(coalesce(former_labels, '')) LIKE :t",
      t: term
    )
  end
end
