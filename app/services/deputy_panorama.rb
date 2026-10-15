# Comparação entre todos os deputados em exercício: governismo de cada um,
# blocos contados deputado a deputado, indicadores lado a lado e frases de
# destaque geradas a partir dos números. A comparação lado a lado de alguns
# deputados escolhidos fica em DeputyComparison.
class DeputyPanorama
  # Votações com orientação Sim/Não do Governo e voto Sim/Não do deputado para medir o governismo
  MIN_GOVERNMENT_POLLS = PartyComparison::MIN_GOVERNMENT_POLLS
  # Votações mínimas no período de mandato para entrar no destaque de participação
  MIN_PARTICIPATION_POLLS = 20
  # Votações mínimas com maioria do partido para entrar no destaque de votos contra o partido
  MIN_ALIGNMENT_POLLS = 20

  BLOCS = PartyComparison::BLOCS
  NO_DATA = PartyComparison::NO_DATA
  MAJORITY = PartyComparison::MAJORITY

  SORTS = {
    "name" => { label: "Deputado", value: :name, default: :asc },
    "party" => { label: "Partido", value: :party_label, default: :asc },
    "state" => { label: "UF", value: :state, default: :asc },
    "governism" => { label: "Governismo", value: :governism_pct, default: :desc },
    "alignment" => { label: "Alinhamento ao partido", value: :alignment_pct, default: :desc },
    "against" => { label: "Votos contra o partido", value: :against, default: :desc },
    "participation" => { label: "Participação", value: :participation_pct, default: :desc },
    "expenses" => { label: "Gasto mensal", value: :monthly, default: :desc },
    "bills" => { label: "Projetos de lei", value: :bills, default: :desc }
  }.freeze

  # Seções da página do panorama, na ordem em que aparecem. A página usa os
  # títulos e as explicações (reading e how); a Harpia recebe os mesmos textos,
  # mais o tipo de gráfico (chart), para reconhecer o gráfico citado pelo
  # usuário (PageGuide). Ver PartyComparison::SECTIONS.
  SECTIONS = {
    "insights" => {
      title: "O que os números mostram",
      chart: "cartões com frases de destaque calculadas a partir dos números dos deputados"
    },
    "blocs" => {
      title: "A Câmara em blocos, deputado a deputado",
      chart: "barra horizontal dividida pelo número de deputados de cada bloco (governista, centro e oposição)",
      reading: "A linha marca as #{MAJORITY} cadeiras da maioria absoluta.",
      how: "Cada deputado entra num bloco pelo próprio governismo: a porcentagem de votações com orientação " \
           "Sim/Não do Governo em que votou igual. São necessárias ao menos #{MIN_GOVERNMENT_POLLS} votações."
    },
    "positioning" => {
      title: "Mapa de posicionamento",
      chart: "gráfico de pontos, um por deputado, colorido pelo bloco",
      reading: "Cada ponto é um deputado. Para a direita, mais votos com o Governo; " \
               "para cima, mais votos com a maioria do próprio partido."
    },
    "indicators" => {
      title: "Indicadores lado a lado",
      chart: "tabela com os indicadores de cada deputado, ordenável por coluna, com filtros de estado e partido"
    }
  }.freeze

  Row = Struct.new(:deputy, :governism, :bloc, :alignment, :participation, :monthly, :bills, :reelection,
                   keyword_init: true) do
    def name = deputy.name
    def party_label = deputy.party.label
    def state = deputy.state_label
    def governism_pct = governism&.dig(:pct)
    def alignment_pct = alignment&.dig(:pct)
    def against = alignment&.dig(:against)
    def participation_pct = participation&.dig(:pct)
  end

  attr_reader :year

  def initialize(year: DeputyMetrics.reference_year, min_government_polls: MIN_GOVERNMENT_POLLS)
    @year = year
    @min_government_polls = min_government_polls
  end

  # Uma linha por deputado em exercício, em ordem alfabética
  def rows
    @rows ||= Deputy.includes(:party).order(:name, :id).map { |deputy| build_row(deputy) }
  end

  # Linhas filtradas (estado, partido) e ordenadas pela coluna pedida; quem não tem o dado fica por último
  def sorted_rows(key, direction, state: nil, party_id: nil)
    sort = SORTS.fetch(key)
    selected = rows.select do |row|
      (state.blank? || row.state == state) && (party_id.blank? || row.deputy.party_id == party_id.to_i)
    end
    present, missing = selected.partition { |row| !row.public_send(sort[:value]).nil? }
    present = present.sort_by { |row| [row.public_send(sort[:value]), row.name] }
    present = present.reverse if direction == :desc
    present + missing
  end

  # { bloc => { deputies: [Row], count: } } na ordem de BLOCS, com os deputados sem dados no fim
  def blocs
    @blocs ||= (BLOCS.keys + [NO_DATA]).to_h do |bloc|
      members = rows.select { |row| row.bloc == bloc }
      [bloc, { deputies: members, count: members.size }]
    end
  end

  def total = rows.size

  # Deputados com governismo e alinhamento: os pontos do mapa de posicionamento
  def positioned
    rows.select { |row| row.governism && row.alignment_pct }
  end

  # Deputados num bloco diferente do da maioria dos colegas de partido
  def off_bloc
    @off_bloc ||= begin
      party_blocs = rows.reject { |row| row.bloc == NO_DATA }.group_by { |row| row.deputy.party_id }
                        .transform_values do |members|
        members.map(&:bloc).tally.max_by do |bloc, count|
          [count, bloc]
        end.first
      end
      rows.select { |row| row.bloc != NO_DATA && party_blocs[row.deputy.party_id] != row.bloc }
          .map { |row| [row, party_blocs[row.deputy.party_id]] }
    end
  end

  # [[ícone, título, texto]] com as leituras que os números permitem
  def insights
    @insights ||= [
      blocs_insight, off_bloc_insight, against_party_insight, participation_insight,
      expenses_insight, bills_insight, reelection_insight
    ].compact
  end

  # Média de cada coluna da tabela entre os deputados que têm o dado.
  # Sem argumento, a da Câmara inteira; com as linhas de um filtro, a do recorte.
  # reelection é a % de candidatos à reeleição.
  def averages(selected = nil) = selected ? averages_of(selected) : chamber_averages

  def chamber_monthly
    values = expenses.values.map { |row| row[:monthly] }
    values.empty? ? nil : values.sum / values.size
  end

  private

  AVERAGED = %i[governism_pct alignment_pct against participation_pct monthly bills].freeze

  def chamber_averages = @chamber_averages ||= averages_of(rows)

  def averages_of(selected)
    AVERAGED.to_h do |column|
      values = selected.filter_map { |row| row.public_send(column) }
      [column, values.empty? ? nil : values.sum.to_f / values.size]
    end.merge(reelection: DeputyMetrics.percentage(selected.count(&:reelection), selected.size))
  end

  # ----- LINHAS -----

  def build_row(deputy)
    governism = government_alignment[deputy.id]
    Row.new(
      deputy: deputy,
      governism: governism,
      bloc: bloc_for(governism),
      alignment: alignment[deputy.id],
      participation: participation[deputy.id],
      monthly: expenses.dig(deputy.id, :monthly),
      bills: bill_counts[deputy.id].to_i,
      reelection: reelection_ids.include?(deputy.id)
    )
  end

  def bloc_for(governism)
    return NO_DATA unless governism

    BLOCS.find { |_, bloc| governism[:pct] >= bloc[:min] }.first
  end

  # { deputy_id => { followed:, total:, pct: } }
  # Votações com orientação Sim/Não do Governo em que o deputado votou Sim ou Não, e em quantas votou igual.
  def government_alignment
    @government_alignment ||= DeputyMetrics.cached("government-alignment/#{@min_government_polls}",
                                                   Vote, PollOrientation) do
      orientations = PollOrientation.where(label: PartyComparison::GOVERNMENT_LABEL,
                                           orientation: PollOrientation::DECISIVE)
                                    .pluck(:poll_id, :orientation).to_h
      result = Hash.new { |hash, key| hash[key] = { followed: 0, total: 0 } }
      Vote.where(vote: Vote::DECISIVE, poll_id: orientations.keys).pluck(:deputy_id, :poll_id, :vote)
          .each do |deputy_id, poll_id, vote|
            result[deputy_id][:total] += 1
            result[deputy_id][:followed] += 1 if vote == orientations[poll_id]
          end

      result.select { |_, row| row[:total] >= @min_government_polls }
            .transform_values { |row| row.merge(pct: DeputyMetrics.percentage(row[:followed], row[:total])) }
    end
  end

  def alignment = @alignment ||= DeputyMetrics.alignment
  def participation = @participation ||= DeputyMetrics.participation
  def expenses = @expenses ||= DeputyMetrics.expenses(year)
  def bill_counts = @bill_counts ||= Bill.count_by_author(Deputy.select(:id))
  def reelection_ids = @reelection_ids ||= Deputy.running_for_reelection.pluck(:id).to_set

  def bloc_phrase(bloc) = { government: "governista", center: "de centro", opposition: "de oposição" }.fetch(bloc)

  def describe(row) = "#{row.name} (#{row.party_label}-#{row.state})"

  # ----- DESTAQUES -----

  def blocs_insight
    government, center, opposition = blocs.values_at(:government, :center, :opposition).map { |bloc| bloc[:count] }
    return if government.zero? && opposition.zero?

    text = "Contando deputado por deputado, #{government} seguem o Governo em #{BLOCS[:government][:min]}% ou mais " \
           "das votações, #{opposition} votam contra ele na maior parte delas e #{center} ficam no meio."
    text += if government >= MAJORITY
              " Os governistas sozinhos passam das #{MAJORITY} cadeiras da maioria absoluta."
            elsif opposition >= MAJORITY
              " A oposição sozinha passa das #{MAJORITY} cadeiras da maioria absoluta."
            else
              " Nenhum lado chega às #{MAJORITY} cadeiras da maioria absoluta sem o centro."
            end
    ["fa-scale-balanced", "Quem decide as votações", text]
  end

  def off_bloc_insight
    return if off_bloc.empty?

    text = "#{off_bloc.size} #{off_bloc.size == 1 ? 'deputado vota' : 'deputados votam'} num bloco diferente " \
           "da maioria do próprio partido."
    # O exemplo é quem está mais longe de um partido governista ou de oposição
    row, party_bloc = off_bloc.reject { |_, bloc| bloc == :center }.max_by do |r, bloc|
      [(r.governism_pct - (bloc == :government ? 100 : 0)).abs, r.governism[:total]]
    end
    if row
      text += " O caso mais distante: #{describe(row)} seguiu o Governo em #{row.governism_pct}% das votações, " \
              "enquanto a maioria da bancada é #{bloc_phrase(party_bloc)}."
    end
    ["fa-shuffle", "Fora do bloco do partido", text]
  end

  def against_party_insight
    row = rows.select { |r| r.alignment && r.alignment[:total] >= MIN_ALIGNMENT_POLLS }
              .max_by { |r| [r.against, -r.alignment_pct] }
    return unless row&.against&.positive?

    ["fa-person-walking-arrow-right", "Quem mais vota contra o partido",
     "#{describe(row)} votou diferente da maioria da bancada em #{row.against} de #{row.alignment[:total]} " \
     "votações (#{100 - row.alignment_pct}%), o maior número na Câmara."]
  end

  def participation_insight
    ranked = rows.select { |r| r.participation && r.participation[:total] >= MIN_PARTICIPATION_POLLS }
    return if ranked.size < 2

    full = ranked.count { |r| r.participation_pct == 100 }
    lowest = ranked.min_by { |r| [r.participation_pct, r.name] }
    text = "#{describe(lowest)} votou em #{lowest.participation[:voted]} das #{lowest.participation[:total]} " \
           "votações do seu período de mandato (#{lowest.participation_pct}%), a menor participação da Câmara."
    text += " #{full} #{full == 1 ? 'deputado não faltou' : 'deputados não faltaram'} a nenhuma." if full.positive?
    ["fa-check-to-slot", "Presença nas votações", text]
  end

  def expenses_insight
    average = chamber_monthly
    # Gasto zero é quem não usou a cota (ou só tem estorno), não o mais econômico
    ranked = rows.select { |r| r.monthly&.positive? }
    return unless average && ranked.size >= 2

    top = ranked.max_by(&:monthly)
    bottom = ranked.min_by(&:monthly)
    brl = ->(value) { ActiveSupport::NumberHelper.number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".", precision: 0) }
    ["fa-wallet", "Gasto da cota parlamentar",
     "#{describe(top)} gastou em média #{brl.call(top.monthly)} por mês em #{year}, " \
     "#{DeputyMetrics.percentage(top.monthly - average, average)}% acima da média da Câmara (#{brl.call(average)}). " \
     "O menor gasto é o de #{describe(bottom)}: #{brl.call(bottom.monthly)} por mês."]
  end

  def bills_insight
    top = rows.max_by { |r| [r.bills, r.name] }
    return unless top&.bills&.positive?

    none = rows.count { |r| r.bills.zero? }
    text = "#{describe(top)} é quem mais apresentou projetos de lei (#{top.bills}, como autor ou coautor)."
    text += " #{none} #{none == 1 ? 'deputado não apresentou' : 'deputados não apresentaram'} nenhum." if none.positive?
    ["fa-file-lines", "Projetos de lei", text]
  end

  def reelection_insight
    count = reelection_ids.size
    return if count.zero?

    ["fa-rotate", "Candidatos à reeleição",
     "#{count} dos #{total} deputados em exercício (#{DeputyMetrics.percentage(count, total)}%) " \
     "são candidatos a deputado federal de novo em 2026."]
  end
end
