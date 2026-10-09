# Comparação entre todos os partidos com bancada na Câmara: posicionamento
# (governismo × coesão), blocos, indicadores lado a lado, afinidade entre
# bancadas e frases de destaque geradas a partir dos números.
class PartyComparison
  # Votações com orientação do Governo (Sim/Não) e voto do partido para medir o governismo
  MIN_GOVERNMENT_POLLS = 20
  GOVERNMENT_LABEL = "Governo".freeze
  # Cadeiras para aprovar projeto de lei complementar / maioria absoluta da Câmara
  MAJORITY = 257
  # Bancada mínima para o destaque de gastos (com 1 ou 2 deputados, a média é de uma pessoa)
  MIN_EXPENSE_SEATS = 5
  # Abaixo disso, a adesão à liderança vira destaque; acima, o destaque é a disciplina geral
  LOW_ADHERENCE = 90
  # Candidaturas mínimas para entrar no destaque de mulheres candidatas
  MIN_CANDIDATES = 20
  # Cota mínima de candidaturas de cada gênero (Lei 9.504/97, art. 10, § 3º)
  GENDER_QUOTA = 30

  # Faixas de governismo (% de votações em que a maioria da bancada seguiu o Governo)
  BLOCS = {
    government: { label: "Governista", min: 90, description: "segue o Governo em 90% ou mais das votações" },
    center:     { label: "Centro",     min: 50, description: "segue o Governo na maior parte das votações, mas não sempre" },
    opposition: { label: "Oposição",   min: 0,  description: "vota contra o Governo na maior parte das votações" }
  }.freeze
  NO_DATA = :no_data

  SORTS = {
    "seats"         => { label: "Cadeiras",           value: :seats,          default: :desc },
    "label"         => { label: "Partido",            value: :label,          default: :asc },
    "states"        => { label: "Estados",            value: :states,         default: :desc },
    "governism"     => { label: "Governismo",         value: :governism_pct,  default: :desc },
    "cohesion"      => { label: "Coesão",             value: :cohesion,       default: :desc },
    "adherence"     => { label: "Segue a liderança",  value: :adherence,      default: :desc },
    "participation" => { label: "Participação",       value: :participation,  default: :desc },
    "expenses"      => { label: "Gasto mensal",       value: :monthly,        default: :desc },
    "bills"         => { label: "Projetos/deputado",  value: :bills_per_deputy, default: :desc },
    "women"         => { label: "Mulheres em 2026",   value: :women_pct,      default: :desc }
  }.freeze

  Row = Struct.new(:party, :seats, :seats_at_start, :states, :top_state, :cohesion, :governism,
                   :adherence, :participation, :monthly, :bills_per_deputy, :top_theme,
                   :candidates, :women_pct, :reelection, :bloc, keyword_init: true) do
    def label = party.label
    def governism_pct = governism&.dig(:pct)

    def bench_change
      seats - seats_at_start if seats_at_start
    end
  end

  attr_reader :year

  def initialize(year: DeputyMetrics.reference_year, min_government_polls: MIN_GOVERNMENT_POLLS)
    @year = year
    @min_government_polls = min_government_polls
  end

  # Uma linha por partido com deputado em exercício, da maior bancada para a menor
  def rows
    @rows ||= begin
      parties = Party.where(id: seats.keys).index_by(&:id)
      seats.sort_by { |party_id, count| [-count, parties[party_id].label] }.map do |party_id, count|
        build_row(parties[party_id], count)
      end
    end
  end

  # Linhas ordenadas pela coluna pedida; quem não tem o dado fica por último
  def sorted_rows(key, direction)
    sort = SORTS.fetch(key)
    present, missing = rows.partition { |row| !row.public_send(sort[:value]).nil? }
    present = present.sort_by { |row| [row.public_send(sort[:value]), -row.seats] }
    present = present.reverse if direction == :desc
    present + missing
  end

  # { bloc => { parties: [Row], seats: } } na ordem de BLOCS, com os partidos sem dados no fim
  def blocs
    @blocs ||= (BLOCS.keys + [NO_DATA]).to_h do |bloc|
      members = rows.select { |row| row.bloc == bloc }
      [bloc, { parties: members, seats: members.sum(&:seats) }]
    end
  end

  def total_seats
    rows.sum(&:seats)
  end

  # Partidos com governismo e coesão: os pontos do mapa de posicionamento
  def positioned
    rows.select { |row| row.governism && row.cohesion }
  end

  # { parties: [Row], cells: { [id_a, id_b] => { same:, common:, pct: } } }
  # Ordenados do mais governista ao mais oposicionista, para os blocos aparecerem juntos
  def affinity
    @affinity ||= begin
      matrix = DeputyMetrics.party_affinity
      parties = rows.select { |row| matrix.key?(row.party.id) }
                    .sort_by { |row| [-(row.governism_pct || -1), -row.seats] }
      cells = {}
      parties.combination(2).each do |a, b|
        cell = matrix.dig(a.party.id, b.party.id)
        next unless cell && cell[:common] >= PartyStats::AFFINITY_MIN_POLLS

        cells[[a.party.id, b.party.id]] = cells[[b.party.id, a.party.id]] = cell
      end
      { parties: parties, cells: cells }
    end
  end

  # [[ícone, título, texto]] com as leituras que os números permitem
  def insights
    @insights ||= [
      majority_insight, government_extremes_insight, center_insight, cohesion_insight,
      cross_bloc_insight, adherence_insight, bench_change_insight, expenses_insight, women_insight
    ].compact
  end

  def chamber_monthly
    values = expenses.values.map { |row| row[:monthly] }
    values.empty? ? nil : values.sum / values.size
  end

  private

  # ----- LINHAS -----

  def build_row(party, count)
    deputy_ids = deputy_ids_by_party[party.id]
    states = state_seats[party.id]
    top_state, top_seats = states.max_by { |state, seats| [seats, state] }
    candidates = candidate_counts[party.id].to_i
    governism = government_alignment[party.id]

    Row.new(
      party: party,
      seats: count,
      seats_at_start: party.seats_at_start,
      states: states.size,
      top_state: { state: top_state, seats: top_seats, pct: DeputyMetrics.percentage(top_seats, count) },
      cohesion: DeputyMetrics.party_cohesion.dig(party.id, :pct),
      governism: governism,
      adherence: PartyStats.new(party, []).orientation_adherence(0)&.dig(:pct),
      participation: average(deputy_ids.filter_map { |id| participation.dig(id, :pct) })&.round,
      monthly: average(deputy_ids.filter_map { |id| expenses.dig(id, :monthly) }),
      bills_per_deputy: (bill_counts[party.id].to_f / count).round(1),
      top_theme: top_themes[party.id],
      candidates: candidates,
      women_pct: DeputyMetrics.percentage(women_counts[party.id].to_i, candidates),
      reelection: reelection_counts[party.id].to_i,
      bloc: bloc_for(governism)
    )
  end

  def bloc_for(governism)
    return NO_DATA unless governism

    BLOCS.find { |_, bloc| governism[:pct] >= bloc[:min] }.first
  end

  # { party_id => { followed:, total:, pct: } }
  # Votações com orientação Sim/Não do Governo em que a maioria da bancada votou igual.
  # Conta a maioria de qualquer bancada (mesmo de 1 ou 2 deputados), sem o piso da coesão.
  def government_alignment
    @government_alignment ||= begin
      orientations = PollOrientation.where(label: GOVERNMENT_LABEL, orientation: PollOrientation::DECISIVE)
                                    .pluck(:poll_id, :orientation).to_h
      votes = Hash.new { |hash, key| hash[key] = { sim: 0, nao: 0 } }
      Vote.joins(:deputy).where(vote: Vote::DECISIVE, poll_id: orientations.keys)
          .group("deputies.party_id", :poll_id, :vote).count
          .each { |(party_id, poll_id, vote), count| votes[[party_id, poll_id]][vote == "Sim" ? :sim : :nao] = count }

      result = Hash.new { |hash, key| hash[key] = { followed: 0, total: 0 } }
      votes.each do |(party_id, poll_id), row|
        majority = DeputyMetrics.majority_of(row[:sim], row[:nao])
        next unless majority

        result[party_id][:total] += 1
        result[party_id][:followed] += 1 if majority == orientations[poll_id]
      end

      result.select { |_, row| row[:total] >= @min_government_polls }
            .transform_values { |row| row.merge(pct: DeputyMetrics.percentage(row[:followed], row[:total])) }
    end
  end

  def seats = @seats ||= Deputy.group(:party_id).count

  def deputy_ids_by_party
    @deputy_ids_by_party ||= Deputy.pluck(:party_id, :id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  def state_seats
    @state_seats ||= Deputy.group(:party_id, :state_label).count
                           .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((party_id, state), count), result|
                             result[party_id][state] = count
                           end
  end

  def participation = @participation ||= DeputyMetrics.participation
  def expenses = @expenses ||= DeputyMetrics.expenses(year)
  def bill_counts = @bill_counts ||= Bill.group(:party_id).count
  def candidate_counts = @candidate_counts ||= Candidate.group(:party_id).count
  def women_counts = @women_counts ||= Candidate.where(gender: "FEMININO").group(:party_id).count
  def reelection_counts = @reelection_counts ||= Candidate.reelection.group(:party_id).count

  # { party_id => Theme } com mais projetos de lei do partido
  def top_themes
    @top_themes ||= begin
      counts = BillTheme.joins(:bill).group("bills.party_id", :theme_id).count
      best = counts.group_by { |(party_id, _), _| party_id }
                   .transform_values { |pairs| pairs.max_by { |(_, theme_id), count| [count, -theme_id] }.first.last }
      themes = Theme.where(id: best.values).index_by(&:id)
      best.transform_values { |theme_id| themes[theme_id] }
    end
  end

  def average(values)
    values.empty? ? nil : values.sum / values.size
  end

  # ----- DESTAQUES -----

  def majority_insight
    government, center, opposition = blocs.values_at(:government, :center, :opposition).map { |bloc| bloc[:seats] }
    return if government.zero? && opposition.zero?

    text =
      if government >= MAJORITY
        "Os partidos governistas somam #{government} cadeiras, acima das #{MAJORITY} da maioria absoluta: o Governo não depende do centro."
      elsif opposition >= MAJORITY
        "A oposição soma #{opposition} cadeiras, acima das #{MAJORITY} da maioria absoluta."
      else
        "Governistas somam #{government} cadeiras e a oposição, #{opposition}. Nenhum lado chega às #{MAJORITY} " \
          "da maioria absoluta sozinho: os #{center} deputados do centro decidem as votações."
      end
    ["fa-scale-balanced", "Quem decide as votações", text]
  end

  def government_extremes_insight
    ranked = rows.select(&:governism).sort_by { |row| [-row.governism_pct, -row.seats] }
    return if ranked.size < 2

    top, bottom = ranked.first, ranked.last
    ["fa-arrows-left-right", "Do mais governista ao mais oposicionista",
     "#{top.label} acompanhou o Governo em #{top.governism_pct}% das votações; #{bottom.label}, em apenas " \
       "#{bottom.governism_pct}%. É a maior distância de comportamento entre bancadas na Câmara."]
  end

  def center_insight
    center = blocs[:center][:parties].sort_by { |row| [-row.governism_pct, -row.seats] }
    return if center.size < 2

    closest, farthest = center.first, center.last
    ["fa-arrows-to-dot", "O centro não é um bloco só",
     "Entre os #{center.size} partidos de centro, #{closest.label} é o mais próximo do Governo (#{closest.governism_pct}%) " \
       "e #{farthest.label} o mais distante (#{farthest.governism_pct}%). São esses partidos que o Governo e a oposição disputam voto a voto."]
  end

  def cohesion_insight
    ranked = rows.select(&:cohesion).sort_by { |row| [-row.cohesion, -row.seats] }
    return if ranked.size < 2

    top, bottom = ranked.first, ranked.last
    ["fa-people-group", "Bancadas unidas e divididas",
     "#{top.label} é a bancada que mais vota unida (#{top.cohesion}% de coesão). #{bottom.label} é a mais dividida " \
       "(#{bottom.cohesion}%): seus deputados se separam com frequência na mesma votação."]
  end

  # O par de partidos de blocos diferentes que mais vota igual
  def cross_bloc_insight
    blocs_by_id = rows.to_h { |row| [row.party.id, row] }
    pairs = affinity[:cells].filter_map do |(a_id, b_id), cell|
      a, b = blocs_by_id.values_at(a_id, b_id)
      next if a_id > b_id || a.bloc == b.bloc || [a.bloc, b.bloc].include?(NO_DATA)

      [a, b, cell]
    end
    a, b, cell = pairs.max_by { |_, _, cell| [cell[:pct], cell[:common]] }
    return unless cell

    ["fa-handshake", "Afinidade além do bloco",
     "#{a.label} (#{BLOCS[a.bloc][:label].downcase}) e #{b.label} (#{BLOCS[b.bloc][:label].downcase}) votaram do mesmo lado " \
       "em #{cell[:pct]}% das #{cell[:common]} votações em comum, a maior afinidade entre partidos de blocos diferentes."]
  end

  def adherence_insight
    ranked = rows.select(&:adherence)
    row = ranked.min_by { |r| [r.adherence, -r.seats] }
    return unless row

    if row.adherence < LOW_ADHERENCE
      ["fa-bullhorn", "Quem menos segue a própria liderança",
       "No partido #{row.label}, a maioria da bancada seguiu a orientação do líder em #{row.adherence}% das votações, " \
         "o menor índice entre os partidos."]
    else
      ["fa-bullhorn", "Lideranças são obedecidas",
       "Nos #{ranked.size} partidos com orientação de liderança registrada, a maioria da bancada seguiu o líder em " \
         "#{row.adherence}% ou mais das votações. As divergências aparecem no voto de deputados isolados, não da bancada."]
    end
  end

  def bench_change_insight
    changes = rows.select(&:bench_change).reject { |row| row.bench_change.zero? }
    return if changes.empty?

    grew = changes.max_by(&:bench_change)
    shrank = changes.min_by(&:bench_change)
    parts = []
    parts << "#{grew.label} foi o que mais ganhou deputados desde a posse (#{format('%+d', grew.bench_change)})" if grew.bench_change.positive?
    parts << "#{shrank.label} o que mais perdeu (#{format('%+d', shrank.bench_change)})" if shrank.bench_change.negative?
    return if parts.empty?

    ["fa-people-arrows", "Trocas de partido", "#{parts.join(', e ')}, com trocas de legenda, licenças e suplências."]
  end

  def expenses_insight
    average = chamber_monthly
    row = rows.select { |r| r.monthly && r.seats >= MIN_EXPENSE_SEATS }.max_by(&:monthly)
    return unless average && row

    diff = DeputyMetrics.percentage(row.monthly - average, average)
    amount = ActiveSupport::NumberHelper.number_to_currency(row.monthly, unit: "R$ ", separator: ",", delimiter: ".", precision: 0)
    ["fa-wallet", "Gasto da cota parlamentar",
     "Os deputados do partido #{row.label} gastam em média #{amount} por mês em #{year}, " \
       "#{diff}% acima da média da Câmara, o maior gasto entre as bancadas."]
  end

  def women_insight
    ranked = rows.select { |row| row.candidates >= MIN_CANDIDATES && row.women_pct }
    return if ranked.size < 2

    top = ranked.max_by { |row| [row.women_pct, row.candidates] }
    below = ranked.select { |row| row.women_pct < GENDER_QUOTA }
    text = "#{top.label} tem a maior proporção de mulheres entre os candidatos a deputado federal em 2026 (#{top.women_pct}%)."
    text += if below.any?
              labels = below.map(&:label).to_sentence(two_words_connector: " e ", last_word_connector: " e ")
              " #{labels} #{below.size == 1 ? 'fica' : 'ficam'} abaixo de #{GENDER_QUOTA}% no total " \
                "(a lei exige ao menos #{GENDER_QUOTA}% de cada gênero na lista de cada estado)."
            else
              " Todos os partidos com bancada têm ao menos #{GENDER_QUOTA}% de mulheres entre os candidatos, a cota mínima por gênero."
            end
    ["fa-venus", "Mulheres nas candidaturas", text]
  end
end
