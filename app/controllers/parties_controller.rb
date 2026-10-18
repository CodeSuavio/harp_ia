class PartiesController < ApplicationController
  include PartyOverview

  skip_before_action :authenticate_user!, only: %i[index show compare]

  COMPARE_LIMIT = PartySelectionComparison::LIMIT

  TABS = {
    "overview" => "Visão geral",
    "votes" => "Votações",
    "expenses" => "Gastos",
    "bills" => "Projetos de lei",
    "candidates" => "Candidatos 2026"
  }.freeze

  STATES = {
    "AC" => "Acre", "AL" => "Alagoas", "AP" => "Amapá", "AM" => "Amazonas",
    "BA" => "Bahia", "CE" => "Ceará", "DF" => "Distrito Federal", "ES" => "Espírito Santo",
    "GO" => "Goiás", "MA" => "Maranhão", "MT" => "Mato Grosso", "MS" => "Mato Grosso do Sul",
    "MG" => "Minas Gerais", "PA" => "Pará", "PB" => "Paraíba", "PR" => "Paraná",
    "PE" => "Pernambuco", "PI" => "Piauí", "RJ" => "Rio de Janeiro", "RN" => "Rio Grande do Norte",
    "RS" => "Rio Grande do Sul", "RO" => "Rondônia", "RR" => "Roraima", "SC" => "Santa Catarina",
    "SP" => "São Paulo", "SE" => "Sergipe", "TO" => "Tocantins"
  }.freeze

  def index
    load_party_overview
  end

  # Aba pedida pela URL; desconhecidas caem na Visão geral. Também usada pela
  # Harpia (PageContextService)
  def self.tab_for(tab) = TABS.key?(tab) ? tab : "overview"

  def show
    @party = Party.find(params[:id])
    authorize @party

    @tab = self.class.tab_for(params[:tab])
    @deputies = @party.deputies.with_attached_photo.order(:name).to_a
    @stats = PartyStats.new(@party, @deputies)
    @candidate_count = @party.candidates.count
  end

  def compare
    authorize Party

    @comparison = PartyComparison.new

    # Partidos escolhidos na listagem (?ids[]=): comparação lado a lado
    if params.key?(:ids)
      @selection = PartySelectionComparison.for(params[:ids], @comparison)
      return render :compare_selected
    end

    @sort = PartyComparison::SORTS.key?(params[:sort]) ? params[:sort] : "seats"
    @direction = %w[asc desc].include?(params[:dir]) ? params[:dir].to_sym : PartyComparison::SORTS[@sort][:default]
    @rows = @comparison.sorted_rows(@sort, @direction)
  end
end
