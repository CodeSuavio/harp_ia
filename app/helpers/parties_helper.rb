module PartiesHelper
  def party_tab_path(party, tab, extra = {})
    party_path(party, { tab: tab }.merge(extra.compact))
  end

  # Opacidade do estado no mapa da bancada: vazio quase apagado, o maior estado cheio
  def bench_map_weight(seats, max_seats)
    seats.zero? ? 0.06 : 0.2 + 0.8 * seats / max_seats
  end

  # "Sim", "Não" ou "Dividida" para a maioria da bancada numa votação
  def bench_position(votes)
    DeputyMetrics.majority_of(votes[:sim], votes[:nao]) || "Dividida"
  end
end
