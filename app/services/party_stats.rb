# Indicadores de um partido: gastos da bancada, comportamento nas votações,
# projetos de lei e candidaturas de 2026. As contas que comparam partidos
# entre si (coesão, afinidade) ficam em DeputyMetrics, com cache.
class PartyStats
  # Votações em comum mínimas para comparar duas bancadas (com poucas, o % oscila demais)
  AFFINITY_MIN_POLLS = 20
  AFFINITY_LIMIT = 3
  # Votos Sim/Não mínimos para o deputado entrar na lista de quem mais vota contra o partido
  DISSIDENT_MIN_VOTES = 20
  DISSIDENTS = 5
  CONTESTED_POLLS = 6
  # Federação que não orienta há mais tempo que isso já não está na Câmara
  FEDERATION_RECENCY = 90.days
  TOP_SPENDERS = 3
  TOP_EXPENSE_TYPES = 5
  RECENT_BILLS = 5
  TOP_THEMES = 5
  NOT_INFORMED = "Não informado".freeze

  attr_reader :party, :deputies

  def initialize(party, deputies = party.deputies.to_a)
    @party = party
    @deputies = deputies
  end

  # ----- BANCADA -----

  # [[UF, deputados]] do maior para o menor
  def state_bench
    @state_bench ||= deputies.group_by(&:state_label).transform_values(&:size).sort_by { |state, count| [-count, state] }
  end

  # Variação desde a posse da legislatura (trocas de partido, licenças e suplências)
  def bench_change
    deputies.size - party.seats_at_start if party.seats_at_start
  end

  # ----- GASTOS -----

  # { year:, total:, deputies:, monthly:, chamber_monthly:, top:, types: }
  # monthly = média do gasto mensal dos deputados do partido com despesas no ano
  def expenses
    return @expenses if defined?(@expenses)

    year = DeputyMetrics.reference_year
    data = year ? DeputyMetrics.expenses(year) : {}
    rows = deputies.filter_map { |deputy| [deputy, data[deputy.id]] if data[deputy.id] }
    return @expenses = nil if rows.empty?

    types = Expense.where(year: year, deputy_id: rows.map { |deputy, _| deputy.id })
                   .group(:expense_type).sum(:net_amount)
                   .sort_by { |_, total| -total }.first(TOP_EXPENSE_TYPES)

    @expenses = {
      year: year,
      total: rows.sum { |_, row| row[:total] },
      deputies: rows.size,
      monthly: average(rows.map { |_, row| row[:monthly] }),
      chamber_monthly: average(data.values.map { |row| row[:monthly] }),
      top: rows.sort_by { |_, row| -row[:monthly] }.first(TOP_SPENDERS).map { |deputy, row| [deputy, row[:monthly]] },
      types: types
    }
  end

  # ----- VOTAÇÕES -----

  def cohesion
    DeputyMetrics.party_cohesion[party.id]
  end

  # [[votação, { sim:, nao:, index: }]] em que a bancada mais se dividiu
  def divided_polls(limit = 5)
    return [] unless cohesion

    rows = cohesion[:by_poll].reject { |_, row| row[:index] == 1 }
                             .sort_by { |poll_id, row| [row[:index], -poll_id] }
                             .first(limit)
    with_polls(rows)
  end

  # { closest: [[partido, { same:, common:, pct: }]], farthest: [...] }
  def affinity(min_polls: AFFINITY_MIN_POLLS)
    rows = DeputyMetrics.party_affinity.fetch(party.id, {}).select { |_, row| row[:common] >= min_polls }
    return if rows.empty?

    parties = Party.where(id: rows.keys).index_by(&:id)
    sorted = rows.sort_by { |id, row| [-row[:pct], parties[id].label] }.map { |id, row| [parties[id], row] }
    closest = sorted.first(AFFINITY_LIMIT)
    { closest: closest, farthest: (sorted - closest).last(AFFINITY_LIMIT).reverse }
  end

  # [[deputado, { aligned:, total:, against:, pct: }]] de quem menos acompanha a maioria do partido
  def dissidents(min_votes: DISSIDENT_MIN_VOTES)
    alignment = DeputyMetrics.alignment
    deputies.filter_map do |deputy|
      row = alignment[deputy.id]
      [deputy, row] if row && row[:total] >= min_votes && row[:against].positive?
    end.sort_by { |deputy, row| [row[:pct], deputy.name] }.first(DISSIDENTS)
  end

  # { poll_id => "Sim" | "Não" | "Liberado" | "Obstrução" }: a orientação da liderança
  # do partido ou, quando ele não orienta sozinho, a da federação de que faz parte
  def orientations
    @orientations ||= begin
      own = PollOrientation.where(party_id: party.id).pluck(:poll_id, :orientation).to_h
      federation = PollOrientation.federations.pluck(:poll_id, :label, :orientation)
                                  .select { |_, label, _| member?(label) }
                                  .to_h { |poll_id, _, orientation| [poll_id, orientation] }
      federation.merge(own)
    end
  end

  # { followed:, total:, pct:, against: [[votação, { sim:, nao:, orientation: }]] }
  # Em quantas votações com orientação Sim/Não a maioria da bancada seguiu a liderança
  def orientation_adherence(limit = 5)
    return unless cohesion

    rows = orientations.filter_map do |poll_id, orientation|
      votes = cohesion[:by_poll][poll_id]
      next unless votes && PollOrientation::DECISIVE.include?(orientation)

      majority = DeputyMetrics.majority_of(votes[:sim], votes[:nao])
      [poll_id, votes.merge(orientation: orientation), majority == orientation] if majority
    end
    return if rows.empty?

    against = rows.reject(&:last).sort_by { |poll_id, _, _| -poll_id }.first(limit).map { |poll_id, row, _| [poll_id, row] }
    followed = rows.count(&:last)
    { followed: followed, total: rows.size, pct: DeputyMetrics.percentage(followed, rows.size), against: with_polls(against) }
  end

  # { label: "PT-PCdoB-PV", parties: [Party] } da federação que orientou recentemente na Câmara
  def federation
    return @federation if defined?(@federation)

    recent = PollOrientation.federations.joins(:poll).group(:label).maximum("polls.date")
    latest = recent.values.max
    label = recent.select { |_, date| date >= latest - FEDERATION_RECENCY }.keys.find { |l| member?(l) } if latest
    return @federation = nil unless label

    siglas = PollOrientation.federation_members(label)
    @federation = {
      label: label.delete_prefix(PollOrientation::FEDERATION_PREFIX),
      parties: Party.where("upper(label) IN (?)", siglas).order(:label).to_a
    }
  end

  # [[votação, { party: {sim:, nao:}, total: {sim:, nao:}, orientation: }]] das votações com
  # placar mais apertado na Câmara (entre as de quórum amplo) em que a bancada votou
  def contested_polls
    return [] unless cohesion

    totals = DeputyMetrics.poll_totals
    # Quórum amplo: ao menos metade dos votos Sim/Não da votação mais concorrida
    quorum = totals.values.map { |row| row[:sim] + row[:nao] }.max.to_i / 2
    margins = cohesion[:by_poll].keys.filter_map do |poll_id|
      total = totals[poll_id]
      voters = total ? total[:sim] + total[:nao] : 0
      [poll_id, (total[:sim] - total[:nao]).abs.to_f / voters] if voters.positive? && voters >= quorum
    end

    rows = margins.sort_by { |poll_id, margin| [margin, -poll_id] }.first(CONTESTED_POLLS).map do |poll_id, _|
      [poll_id, { party: cohesion[:by_poll][poll_id], total: totals[poll_id], orientation: orientations[poll_id] }]
    end
    with_polls(rows).sort_by { |poll, _| poll.date || Time.at(0) }.reverse
  end

  # ----- PROJETOS -----

  def bills
    Bill.where(party_id: party.id)
  end

  def recent_bills
    bills.includes(:deputy).order(Arel.sql("submission_date DESC NULLS LAST")).limit(RECENT_BILLS)
  end

  # [[tipo, quantidade]], do mais comum para o menos comum
  def bill_types
    bills.group(:bill_type).count.sort_by { |type, count| [-count, type.to_s] }
  end

  # [[tema, quantidade de projetos]]
  def bill_themes
    counts = BillTheme.where(bill_id: bills.select(:id)).group(:theme_id).count
    top = counts.sort_by { |_, count| -count }.first(TOP_THEMES)
    themes = Theme.where(id: top.map(&:first)).index_by(&:id)
    top.filter_map { |theme_id, count| [themes[theme_id], count] if themes[theme_id] }
  end

  # Propostas do programa e do plano de governo do partido (não as de um deputado)
  def proposals
    party.proposals.where(deputy_id: nil).includes(:theme).order(:source_kind, :title)
  end

  # ----- CANDIDATOS 2026 -----

  # { total:, reelection:, women_pct:, chamber_women_pct:, gender:, race:, education:, states: }
  def candidate_profile
    return @candidate_profile if defined?(@candidate_profile)

    scope = party.candidates
    total = scope.count
    return @candidate_profile = nil if total.zero?

    gender = distribution(scope, :gender)
    women = gender.to_h["FEMININO"].to_i
    chamber_total = Candidate.count

    @candidate_profile = {
      total: total,
      reelection: scope.reelection.count,
      women_pct: DeputyMetrics.percentage(women, total),
      chamber_women_pct: DeputyMetrics.percentage(Candidate.where(gender: "FEMININO").count, chamber_total),
      gender: gender,
      race: distribution(scope, :race_color),
      education: distribution(scope, :education_level),
      states: scope.group(:state_label).count.sort_by { |state, count| [-count, state.to_s] }
    }
  end

  private

  def member?(federation_label)
    PollOrientation.federation_members(federation_label).include?(party.label.to_s.upcase)
  end

  # [[valor, quantidade]], com vazios agrupados em "Não informado"
  def distribution(scope, column)
    counts = Hash.new(0)
    scope.group(column).count.each { |value, count| counts[value.presence || NOT_INFORMED] += count }
    counts.sort_by { |value, count| [value == NOT_INFORMED ? 1 : 0, -count, value] }
  end

  # Troca o id da votação pelo registro, mantendo a ordem e descartando as que sumiram
  def with_polls(rows)
    polls = Poll.where(id: rows.map(&:first)).index_by(&:id)
    rows.filter_map { |poll_id, row| [polls[poll_id], row] if polls[poll_id] }
  end

  def average(values)
    values.empty? ? 0 : values.sum / values.size
  end
end
