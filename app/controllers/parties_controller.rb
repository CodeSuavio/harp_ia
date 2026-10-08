class PartiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  DIVIDED_POLLS = 5

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
    parties = policy_scope(Party).order(:label).to_a
    seats = Deputy.group(:state_label, :party_id).count

    @state_seats = Hash.new(0)
    seats.each { |(uf, _), count| @state_seats[uf] += count }

    bench_ids = seats.keys.to_set(&:last)
    with_bench, @parties_without_bench = parties.partition { |p| bench_ids.include?(p.id) }
    @map_data = map_data(with_bench, seats)
    @uf = params[:uf].to_s.upcase.presence_in(STATES.keys)
  end

  def show
    @party = Party.find(params[:id])
    authorize @party

    @deputies = @party.deputies.with_attached_photo.order(:name)
    @candidate_count = @party.candidates.count
    @state_bench = @deputies.group_by(&:state_label).transform_values(&:size).sort_by { |state, count| [-count, state] }

    @cohesion = DeputyMetrics.party_cohesion[@party.id]
    @average_cohesion = DeputyMetrics.average_cohesion
    @alignment = DeputyMetrics.alignment
    @divided_polls = divided_polls
  end

  private

  # Tudo o que o mapa precisa para trocar de estado sem ir ao servidor:
  # { parties: { id => {label, name, url} }, national: { party_id => cadeiras },
  #   states: { "SP" => { name:, seats: { party_id => cadeiras } } } }
  def map_data(parties, seats)
    national = Hash.new(0)
    by_state = Hash.new { |hash, uf| hash[uf] = {} }
    seats.each do |(uf, party_id), count|
      national[party_id] += count
      by_state[uf][party_id] = count
    end

    {
      parties: parties.to_h { |p| [p.id, { label: p.label, name: p.name, url: party_path(p) }] },
      national: national,
      states: STATES.to_h { |uf, name| [uf, { name: name, seats: by_state[uf] }] }
    }
  end

  # [[votação, { sim:, nao:, index: }]] em que a bancada mais se dividiu
  def divided_polls
    return [] unless @cohesion

    rows = @cohesion[:by_poll].reject { |_, row| row[:index] == 1 }
                              .sort_by { |poll_id, row| [row[:index], -poll_id] }
                              .first(DIVIDED_POLLS)
    polls = Poll.where(id: rows.map(&:first)).index_by(&:id)
    rows.filter_map { |poll_id, row| [polls[poll_id], row] if polls[poll_id] }
  end
end
