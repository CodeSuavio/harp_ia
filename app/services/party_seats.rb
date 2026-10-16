# Cadeiras de cada partido na Câmara, no total e em cada estado, como o mapa
# de partidos da página inicial e da lista de partidos mostra.
#
# Usado pelo mapa (PartyOverview) e pela Harpia (PartyRankingTool com estado),
# para os números serem os mesmos nos dois.
class PartySeats
  # { [UF, party_id] => cadeiras }
  attr_reader :seats

  def initialize
    @seats = Deputy.group(:state_label, :party_id).count
  end

  # { UF => cadeiras do estado }
  def state_totals
    seats.each_with_object(Hash.new(0)) { |((uf, _), count), totals| totals[uf] += count }
  end

  # { party_id => cadeiras no estado }
  def in_state(state)
    seats.filter_map { |(uf, party_id), count| [party_id, count] if uf == state }.to_h
  end

  def party_ids
    seats.keys.to_set(&:last)
  end
end
