# Indicadores de TODOS os deputados de uma vez, para listagem, ordenação,
# rankings e comparação. Os resultados ficam em cache até os dados mudarem.
#
# Os indicadores individuais detalhados ficam em DeputyStats; as regras de
# cálculo são as mesmas nos dois lugares.
class DeputyMetrics
  # Cota para o Exercício da Atividade Parlamentar (CEAP): valor mensal por UF.
  # Fonte: Ato da Mesa nº 43/2009 e atualizações; conferir os valores vigentes em
  # https://www2.camara.leg.br/transparencia/acesso-a-informacao/copy_of_perguntas-frequentes/cota-para-o-exercicio-da-atividade-parlamentar
  CEAP_MONTHLY = {
    "AC" => 50_426.26, "AL" => 46_737.90, "AM" => 49_363.92, "AP" => 49_168.58,
    "BA" => 44_804.65, "CE" => 48_245.57, "DF" => 36_582.46, "ES" => 43_217.71,
    "GO" => 41_300.86, "MA" => 47_945.49, "MG" => 41_886.51, "MS" => 46_336.64,
    "MT" => 45_162.42, "PA" => 48_021.25, "PB" => 47_826.36, "PE" => 47_470.60,
    "PI" => 46_765.57, "PR" => 44_665.66, "RJ" => 41_553.77, "RN" => 48_525.79,
    "RO" => 49_466.29, "RR" => 51_406.33, "RS" => 46_669.70, "SC" => 45_671.24,
    "SE" => 45_933.10, "SP" => 42_837.33, "TO" => 45_297.48
  }.freeze

  # Votos Sim/Não mínimos do partido numa votação para entrar na coesão
  # (com 1 ou 2 votantes o índice é quase sempre 100% e não diz nada)
  COHESION_MIN_VOTERS = 3

  def self.reference_year
    Expense.maximum(:year)
  end

  # ----- GASTOS -----

  # { deputy_id => { total:, months:, monthly: } } no ano (meses = meses com despesa)
  def self.expenses(year = reference_year)
    return {} unless year

    cached("expenses/#{year}", Expense) do
      scope = Expense.where(year: year)
      totals = scope.group(:deputy_id).sum(:net_amount)
      months = scope.group(:deputy_id).distinct.count(:month)
      totals.to_h do |deputy_id, total|
        count = months[deputy_id].to_i
        [deputy_id, { total: total, months: count, monthly: count.zero? ? 0 : total / count }]
      end
    end
  end

  # Posição no ranking de gasto médio mensal (1 = quem mais gasta), na Câmara e no estado
  def self.expense_rank(deputy, year = reference_year)
    data = expenses(year)
    own = data.dig(deputy.id, :monthly)
    return unless own

    state_ids = cached("state-ids/#{deputy.state_label}", Deputy) { Deputy.where(state_label: deputy.state_label).pluck(:id) }
    state_values = data.values_at(*state_ids).compact.map { |row| row[:monthly] }

    {
      position: data.values.count { |row| row[:monthly] > own } + 1,
      total: data.size,
      state_position: state_values.count { |value| value > own } + 1,
      state_total: state_values.size
    }
  end

  # Uso da cota no ano: gasto total / (cota mensal da UF × meses de exercício).
  # Meses de exercício = do primeiro mês com despesa do deputado até o último mês com dados no ano.
  def self.quota_usage(deputy, year = reference_year)
    monthly_quota = CEAP_MONTHLY[deputy.state_label]
    return unless monthly_quota && year

    months = deputy.expenses.where(year: year).distinct.pluck(:month)
    return if months.empty?

    last_month = cached("last-month/#{year}", Expense) { Expense.where(year: year).maximum(:month) }
    exercise_months = last_month - months.min + 1
    quota = monthly_quota * exercise_months
    total = expenses(year).dig(deputy.id, :total).to_f

    { total: total, quota: quota, monthly_quota: monthly_quota, months: exercise_months, pct: (total / quota * 100).round }
  end

  # ----- VOTAÇÕES -----

  # { deputy_id => { voted:, total:, pct:, from:, to: } }
  #
  # O denominador são as votações (com votos registrados) entre o primeiro e o
  # último voto do deputado, para não penalizar suplentes e licenciados pelas
  # votações de antes de assumirem ou de depois de saírem.
  def self.participation
    cached("participation", Vote) do
      poll_dates = Poll.where(id: Vote.select(:poll_id)).pluck(:date).compact.sort

      Vote.joins(:poll).group(:deputy_id)
          .pluck(:deputy_id, Arel.sql("MIN(polls.date)"), Arel.sql("MAX(polls.date)"), Arel.sql("COUNT(*)"))
          .to_h do |deputy_id, from, to, voted|
            [deputy_id, participation_row(voted, count_between(poll_dates, from, to), from, to)]
          end
    end
  end

  def self.participation_row(voted, total, from, to)
    { voted: voted, total: total, pct: percentage(voted, total), from: from, to: to }
  end

  # { deputy_id => { aligned:, total:, against:, pct: } }
  # Maioria do partido calculada sem o voto do próprio deputado; empates não contam.
  def self.alignment
    cached("alignment", Vote) do
      rows = Vote.joins(:deputy).where(vote: Vote::DECISIVE)
                 .pluck(:deputy_id, "deputies.party_id", :poll_id, :vote)

      counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      rows.each { |_, party_id, poll_id, vote| counts[[party_id, poll_id]][vote] += 1 }

      result = Hash.new { |hash, key| hash[key] = { aligned: 0, total: 0 } }
      rows.each do |deputy_id, party_id, poll_id, vote|
        others = counts[[party_id, poll_id]].dup
        others[vote] -= 1
        majority = majority_of(others["Sim"], others["Não"])
        next unless majority

        result[deputy_id][:total] += 1
        result[deputy_id][:aligned] += 1 if majority == vote
      end

      result.transform_values do |row|
        row.merge(against: row[:total] - row[:aligned], pct: percentage(row[:aligned], row[:total]))
      end.to_h
    end
  end

  # { party_id => { pct:, polls:, unanimous:, by_poll: { poll_id => { sim:, nao:, index: } } } }
  #
  # Coesão da bancada pelo índice de Rice: em cada votação, |Sim − Não| / (Sim + Não)
  # (1 = todos votaram igual, 0 = racha meio a meio); o partido recebe a média em %.
  # Só contam votações com pelo menos COHESION_MIN_VOTERS votos Sim/Não do partido.
  def self.party_cohesion
    cached("party-cohesion", Vote) do
      by_party = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = { sim: 0, nao: 0 } } }
      Vote.joins(:deputy).where(vote: Vote::DECISIVE)
          .group("deputies.party_id", :poll_id, :vote).count
          .each { |(party_id, poll_id, vote), count| by_party[party_id][poll_id][vote == "Sim" ? :sim : :nao] = count }

      by_party.filter_map do |party_id, polls|
        by_poll = polls.select { |_, row| row[:sim] + row[:nao] >= COHESION_MIN_VOTERS }
        next if by_poll.empty?

        by_poll = by_poll.transform_values do |row|
          row.merge(index: (row[:sim] - row[:nao]).abs.to_f / (row[:sim] + row[:nao]))
        end
        indexes = by_poll.values.map { |row| row[:index] }

        [party_id, {
          pct: (indexes.sum / indexes.size * 100).round,
          polls: indexes.size,
          unanimous: indexes.count { |index| index == 1 },
          by_poll: by_poll
        }]
      end.to_h
    end
  end

  # Média simples da coesão dos partidos com dados (referência para cada partido)
  def self.average_cohesion
    values = party_cohesion.values.map { |row| row[:pct] }
    values.empty? ? nil : (values.sum.to_f / values.size).round
  end

  # { party_id => { outro_party_id => { same:, common:, pct: } } }
  #
  # Afinidade entre bancadas: nas votações da coesão em que as duas têm maioria
  # (Sim ou Não, sem empate), em quantas a maioria das duas foi a mesma.
  def self.party_affinity
    cached("party-affinity", Vote) { affinity_from(party_cohesion) }
  end

  # Mesma conta de party_affinity a partir de { party_id => { by_poll: { poll_id => { sim:, nao: } } } }
  def self.affinity_from(cohesion)
    majorities = cohesion.transform_values do |row|
      row[:by_poll].filter_map do |poll_id, votes|
        majority = majority_of(votes[:sim], votes[:nao])
        [poll_id, majority] if majority
      end.to_h
    end

    majorities.to_h do |party_id, own|
      others = majorities.except(party_id).to_h do |other_id, theirs|
        common = own.keys & theirs.keys
        same = common.count { |poll_id| own[poll_id] == theirs[poll_id] }
        [other_id, { same: same, common: common.size, pct: percentage(same, common.size) }]
      end
      [party_id, others]
    end
  end

  # { poll_id => { sim:, nao: } } com os votos Sim/Não de toda a Câmara
  def self.poll_totals
    cached("poll-totals", Vote) do
      totals = {}
      Vote.where(vote: Vote::DECISIVE).group(:poll_id, :vote).count.each do |(poll_id, vote), count|
        (totals[poll_id] ||= { sim: 0, nao: 0 })[vote == "Sim" ? :sim : :nao] = count
      end
      totals
    end
  end

  # Quantas votações (com voto dos dois) cada par de deputados votou diferente
  def self.divergence(deputy_a, deputy_b)
    votes_a = deputy_a.votes.pluck(:poll_id, :vote).to_h
    votes_b = deputy_b.votes.pluck(:poll_id, :vote).to_h
    common = votes_a.keys & votes_b.keys
    different = common.count { |poll_id| votes_a[poll_id] != votes_b[poll_id] }
    { common: common.size, different: different, pct: percentage(different, common.size) }
  end

  # ----- PROJETOS -----

  def self.average_bills
    cached("average-bills", Bill, BillAuthor) do
      deputies = Deputy.count
      deputies.zero? ? 0 : (Bill.count_by_author(Deputy.select(:id)).values.sum.to_f / deputies).round(1)
    end
  end

  # ----- AUXILIARES -----

  def self.majority_of(sim, nao)
    return "Sim" if sim > nao
    return "Não" if nao > sim

    nil
  end

  def self.percentage(part, total)
    return nil if total.to_i.zero?

    (part * 100.0 / total).round
  end

  def self.count_between(sorted_dates, from, to)
    return 0 unless from && to

    first = sorted_dates.bsearch_index { |date| date >= from } || sorted_dates.size
    last = sorted_dates.bsearch_index { |date| date > to } || sorted_dates.size
    last - first
  end

  # A chave muda quando a tabela de origem muda (inclusão, remoção ou edição)
  def self.cached(name, *models, &block)
    version = models.flat_map { |model| [model.count, model.maximum(:updated_at)&.to_f] }.join("-")
    Rails.cache.fetch(["deputy-metrics", name, version], &block)
  end
end
