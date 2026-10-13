class PartiesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show compare]

  COMPARE_LIMIT = 4

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

  # A visão geral dos partidos fica na home; mantém links antigos (inclusive ?uf=)
  def index
    skip_policy_scope
    redirect_to root_path(uf: params[:uf].presence, anchor: "partidos"), status: :moved_permanently
  end

  def show
    @party = Party.find(params[:id])
    authorize @party

    @tab = TABS.key?(params[:tab]) ? params[:tab] : "overview"
    @deputies = @party.deputies.with_attached_photo.order(:name).to_a
    @stats = PartyStats.new(@party, @deputies)
    @candidate_count = @party.candidates.count
  end

  def compare
    authorize Party

    @comparison = PartyComparison.new

    # Partidos escolhidos na listagem (?ids[]=): comparação lado a lado
    if params.key?(:ids)
      ids = Array(params[:ids]).reject(&:blank?).first(COMPARE_LIMIT).map(&:to_i)
      rows = @comparison.rows.index_by { |row| row.party.id }
      @selection = PartySelectionComparison.new(rows.values_at(*ids).compact.uniq, @comparison)
      return render :compare_selected
    end

    @sort = PartyComparison::SORTS.key?(params[:sort]) ? params[:sort] : "seats"
    @direction = %w[asc desc].include?(params[:dir]) ? params[:dir].to_sym : PartyComparison::SORTS[@sort][:default]
    @rows = @comparison.sorted_rows(@sort, @direction)
  end
end
