# Bancadas por partido e por estado, para o mapa de partidos da home.
module PartyOverview
  extend ActiveSupport::Concern

  private

  def load_party_overview
    parties = policy_scope(Party).order(:label).to_a
    seats = PartySeats.new

    @state_seats = seats.state_totals

    bench_ids = seats.party_ids
    with_bench, @parties_without_bench = parties.partition { |p| bench_ids.include?(p.id) }
    @map_data = party_map_data(with_bench, seats.seats)
    @uf = params[:uf].to_s.upcase.presence_in(PartiesController::STATES.keys)
  end

  # Tudo o que o mapa precisa para trocar de estado sem ir ao servidor:
  # { parties: { id => {label, name, url, logo} }, national: { party_id => cadeiras },
  #   states: { "SP" => { name:, seats: { party_id => cadeiras } } } }
  def party_map_data(parties, seats)
    national = Hash.new(0)
    by_state = Hash.new { |hash, uf| hash[uf] = {} }
    seats.each do |(uf, party_id), count|
      national[party_id] += count
      by_state[uf][party_id] = count
    end

    {
      parties: parties.to_h do |p|
        [p.id, { label: p.label, name: p.name, url: party_path(p), logo: helpers.party_logo_path(p) }]
      end,
      national: national,
      states: PartiesController::STATES.to_h { |uf, name| [uf, { name: name, seats: by_state[uf] }] }
    }
  end
end
