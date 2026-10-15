# Comparação lado a lado entre os partidos escolhidos na listagem, no mesmo
# formato de DeputyComparison: uma linha por indicador, uma coluna por partido.
#
# Os números vêm das linhas de PartyComparison (os mesmos da tabela geral).
# `better` diz qual direção é melhor; nil = a linha não tem "melhor"
# (governismo, coesão e disciplina não são bons nem ruins em si).
class PartySelectionComparison
  Row = DeputyComparison::Row
  # Partidos comparados de uma vez
  LIMIT = 4

  # Seções da página, na ordem em que aparecem. A página usa a legenda
  # (reading) e a explicação (how); a Harpia recebe os mesmos textos, mais o
  # tipo de gráfico (chart), para reconhecer a seção citada (PageGuide)
  SECTIONS = {
    "table" => {
      title: "Comparação lado a lado",
      chart: "tabela com uma coluna por partido escolhido e uma linha por indicador, marcando o melhor e o " \
             "pior da linha",
      reading: "Gastos menores, mais participação, mais projetos por deputado e mais mulheres candidatas " \
               "contam como melhor. Governismo, coesão e disciplina não têm lado melhor."
    },
    "votes" => {
      title: "Como votaram entre si",
      chart: "lista dos pares de partidos escolhidos, com a % de votações em que as maiorias votaram igual",
      how: "Nas votações em que as duas bancadas tiveram maioria (Sim ou Não), em quantas a maioria das duas " \
           "foi a mesma. Só pares com ao menos #{PartyStats::AFFINITY_MIN_POLLS} votações em comum."
    }
  }.freeze

  attr_reader :parties

  # Partidos escolhidos na listagem (ids na ordem da escolha), como a página
  # monta a comparação: ignora ids vazios, desconhecidos e repetidos, até LIMIT
  def self.for(ids, comparison = PartyComparison.new)
    ids = Array(ids).compact_blank.first(LIMIT).map(&:to_i)
    rows = comparison.rows.index_by { |row| row.party.id }
    new(rows.values_at(*ids).compact.uniq, comparison)
  end

  # parties: [PartyComparison::Row] na ordem em que foram escolhidos
  def initialize(parties, comparison)
    @parties = parties
    @comparison = comparison
  end

  def rows
    @rows ||= [
      row("Deputados", :integer, nil,
          info: "Deputados hoje e variação desde a posse da legislatura.") do |p|
        change = p.bench_change
        { value: p.seats, detail: (format("%+d desde a posse", change) if change && !change.zero?) }
      end,
      row("Estados", :integer, nil, info: "Estados (e DF) com ao menos um deputado do partido.") do |p|
        { value: p.states, detail: "#{p.top_state[:state]} #{p.top_state[:pct]}% da bancada" }
      end,
      row("Governismo", :percent, nil,
          info: "Votações com orientação Sim/Não do Governo em que a maioria da bancada votou igual.") do |p|
        { value: p.governism_pct, detail: bloc_label(p.bloc) }
      end,
      row("Coesão", :percent, nil, value: :cohesion,
                                   info: "Quão unida a bancada vota: 100% quando todos votam igual."),
      row("Segue a liderança", :percent, nil, value: :adherence,
                                              info: "Votações em que a maioria da bancada seguiu a orientação do próprio líder."),
      row("Participação em votações", :percent, :higher, value: :participation,
                                                         info: "Média da participação dos deputados do partido nas votações nominais."),
      row("Gasto médio mensal", :currency, :lower, value: :monthly,
                                                   info: "Média do gasto mensal da cota parlamentar (CEAP) dos deputados em #{@comparison.year}."),
      row("Projetos por deputado", :decimal, :higher, value: :bills_per_deputy,
                                                      info: "Projetos de lei do partido divididos pelos deputados da bancada atual."),
      row("Tema principal", :text, nil, info: "Tema com mais projetos de lei do partido.") do |p|
        { value: p.top_theme&.name }
      end,
      row("Candidatos em 2026", :integer, nil,
          info: "Candidatos do partido a deputado federal em 2026 (TSE).") do |p|
        { value: p.candidates, detail: ("#{p.reelection} à reeleição" if p.reelection.positive?) }
      end,
      row("Mulheres candidatas", :percent, :higher, value: :women_pct,
                                                    info: "Mulheres entre os candidatos do partido a deputado federal em 2026.")
    ]
  end

  # :best / :worst quando a linha tem direção e os valores não são todos iguais
  def highlight(row, party)
    return unless row.better

    numbers = row.values.values.filter_map { |cell| cell[:value] }
    value = row.values.dig(party.party.id, :value)
    return if value.nil? || numbers.size < 2 || numbers.uniq.size < 2

    best, worst = row.better == :higher ? [numbers.max, numbers.min] : numbers.minmax
    return :best if value == best

    :worst if value == worst
  end

  # [[partido A, partido B, { same:, common:, pct: } ou nil]]
  # nil quando as bancadas têm poucas votações em comum para comparar
  def affinities
    matrix = DeputyMetrics.party_affinity
    parties.combination(2).map do |a, b|
      cell = matrix.dig(a.party.id, b.party.id)
      [a, b, (cell if cell && cell[:common] >= PartyStats::AFFINITY_MIN_POLLS)]
    end
  end

  def bloc_label(bloc)
    PartyComparison::BLOCS.dig(bloc, :label) || "Sem dados de governismo"
  end

  private

  # Com `value:`, a célula é só o atributo da linha do partido; com bloco, o bloco monta a célula
  def row(label, format, better, info: nil, value: nil)
    values = parties.to_h do |party|
      [party.party.id, value ? { value: party.public_send(value) } : yield(party)]
    end
    Row.new(label: label, format: format, better: better, info: info, values: values)
  end
end
