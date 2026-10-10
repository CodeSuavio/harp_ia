# Monta a linha do tempo de partidos de um deputado a partir do histórico da API da Câmara
# (GET /deputados/{id}/historico), que vem com registros repetidos e alguns enganosos:
#
# - "Partido no início da legislatura" sai com a data em que a Câmara gerou o histórico e o
#   partido atual, inclusive para legislaturas antigas e para a próxima. Só vale quando a data
#   cai dentro da própria legislatura.
# - Depois de uma mudança de nome ou fusão (PRB → REPUBLICANOS), a sigla antiga ainda aparece
#   em registros seguintes. Ela não conta como troca de partido.
#
# Uso: PartyHistory.new(dados_da_api).entries => [Entry(party_label:, legislature:, started_on:, kind:)]
class PartyHistory
  START_STATUS = "Nome no início da legislatura".freeze

  # Mudanças de sigla entre partidos que já não existem (os atuais ficam em Party#former_labels)
  HISTORICAL_RENAMES = {
    "DEM" => %w[PFL],
    "SD" => %w[SDD],
    "PATRIOTA" => %w[PATRI],
    "PATRI" => %w[PEN]
  }.freeze

  Entry = Struct.new(:party_label, :legislature, :started_on, :kind, keyword_init: true)

  # Período da legislatura (a 57ª começou em 01/02/2023; cada uma dura 4 anos)
  def self.legislature_period(number)
    Date.new(1795 + (4 * number), 2, 1)...Date.new(1799 + (4 * number), 2, 1)
  end

  # { sigla => [siglas anteriores] }: nomes antigos (Party#former_labels e HISTORICAL_RENAMES)
  # e partidos incorporados (Party::MERGERS)
  def self.predecessors
    result = Hash.new { |hash, key| hash[key] = [] }
    Party.pluck(:label, :former_labels).each do |label, former|
      result[label.upcase].concat(former.to_s.upcase.split)
    end
    Party::MERGERS.each { |sigla, merger| result[merger[:succeeded_by].upcase] << sigla.upcase }
    HISTORICAL_RENAMES.each { |label, former| result[label].concat(former) }
    result
  end

  def initialize(records, predecessors: self.class.predecessors)
    @records = records
    @predecessors = predecessors
  end

  def entries
    previous_legislature = nil
    events.each_with_object([]) do |(date, legislature, _, label), result|
      last = result.last
      if last.nil?
        result << Entry.new(party_label: label, legislature: legislature, started_on: date, kind: "first")
      elsif same_party?(last.party_label, label)
        # mesma sigla, ou sigla antiga do partido atual: nada muda
      elsif successor?(last.party_label, label) && last.started_on == date
        # Sigla antiga e nova no mesmo dia: o registro antigo estava desatualizado
        last.party_label = label
      else
        kind = if successor?(last.party_label, label) then "rename"
               elsif legislature != previous_legislature then "new_term"
               else "switch"
               end
        result << Entry.new(party_label: label, legislature: legislature, started_on: date, kind: kind)
      end
      previous_legislature = legislature
    end
  end

  private

  # [[data, legislatura, ordem na API, sigla]] em ordem cronológica
  def events
    @records.each_with_index.filter_map do |record, index|
      date = Date.parse(record["dataHora"].to_s)
      legislature = record["idLegislatura"].to_i
      label = record["siglaPartido"].to_s.strip.upcase
      next if label.empty? || legislature.zero?
      next if record["descricaoStatus"].to_s.start_with?(START_STATUS) &&
              !self.class.legislature_period(legislature).cover?(date)

      [date, legislature, index, label]
    rescue Date::Error
      nil
    end.sort
  end

  def same_party?(current, label)
    current == label || successor?(label, current)
  end

  # `newer` é o mesmo partido com outro nome, ou o partido que incorporou `older` (direta ou indiretamente)
  def successor?(older, newer, seen = Set.new)
    return false unless seen.add?(newer)

    predecessors = @predecessors.fetch(newer, [])
    predecessors.include?(older) || predecessors.any? { |label| successor?(older, label, seen) }
  end
end
