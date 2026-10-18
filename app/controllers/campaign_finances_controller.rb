# Gastos de campanha dos candidatos a deputado federal em 2026: quanto cada um gastou,
# quantos votos teve e quanto custou cada voto (CampaignFinanceRanking).
class CampaignFinancesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  PER_PAGE = 24
  SORTS = {
    "expenses" => "Maior gasto",
    "votes" => "Mais votos",
    "cost_desc" => "Voto mais caro",
    "cost_asc" => "Voto mais barato"
  }.freeze
  RESULTS = {
    "" => "Todos os resultados",
    "elected" => "Eleitos",
    "substitute" => "Suplentes",
    "not_elected" => "Não eleitos"
  }.freeze

  def index
    authorize CampaignFinance
    read_filters

    ranking = CampaignFinanceRanking.new(state: @state, party: @party, result: @result, query: params[:q],
                                         scope: policy_scope(CampaignFinance))
    @summary = ranking.summary
    @quartiles = ranking.spending_quartiles
    @benchmarks = CampaignFinanceRanking.state_benchmarks

    ordered = ranking.ordered(@sort)
    @total = ordered.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @finances = ordered.includes(candidate: [:party, { photo_attachment: :blob }])
                       .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    @states = Candidate.where(id: CampaignFinance.select(:candidate_id)).distinct.pluck(:state_label).compact.sort
    @parties = Party.where(id: Candidate.where(id: CampaignFinance.select(:candidate_id)).select(:party_id)).order(:label)
  end

  private

  def read_filters
    @state = params[:state].presence
    @party = Party.find_by(id: params[:party]) if params[:party].present?
    @result = RESULTS.key?(params[:result].to_s) ? params[:result].to_s : ""
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "expenses"
  end
end
