# Monta a tabela de comparação lado a lado entre deputados.
#
# Cada linha tem o valor bruto (para destacar o melhor e o pior) e um detalhe
# opcional. `better` diz qual direção é melhor; nil = a linha não tem "melhor"
# (ex.: alinhamento com o partido não é bom nem ruim em si).
class DeputyComparison
  Row = Struct.new(:label, :format, :better, :values, :info, keyword_init: true)

  attr_reader :deputies, :year

  def initialize(deputies, year: DeputyMetrics.reference_year)
    @deputies = deputies
    @year = year
  end

  def rows
    @rows ||= [
      row("Gasto total em #{year}", :currency, :lower) { |d| { value: expenses.dig(d.id, :total) } },
      row("Gasto médio mensal", :currency, :lower,
          info: "Total do ano dividido pelos meses com despesa.") { |d| { value: expenses.dig(d.id, :monthly) } },
      row("Uso da cota (CEAP)", :percent, :lower,
          info: "Gasto do ano sobre a cota mensal do estado × meses de exercício.") do |d|
        quota = DeputyMetrics.quota_usage(d, year)
        { value: quota&.dig(:pct) }
      end,
      row("Projetos de lei", :integer, :higher) { |d| { value: bill_counts[d.id].to_i } },
      row("Participação em votações", :percent, :higher,
          info: "Votações registradas entre o primeiro e o último voto do deputado.") do |d|
        data = participation[d.id]
        { value: data&.dig(:pct), detail: ("#{data[:voted]}/#{data[:total]}" if data) }
      end,
      row("Alinhamento com o partido", :percent, nil,
          info: "Votos Sim/Não iguais aos da maioria do partido (sem contar o próprio deputado).") do |d|
        { value: alignment.dig(d.id, :pct) }
      end,
      row("Votos contra o partido", :integer, nil) { |d| { value: alignment.dig(d.id, :against).to_i } },
      row("Coerência com as propostas", :percent, :higher,
          info: "Votos no sentido das propostas cadastradas para o deputado e o partido.") do |d|
        coherence = profiles[d.id].coherence
        { value: coherence[:pct], detail: ("#{coherence[:coherent]}/#{coherence[:total]} votos" if coherence[:total].positive?) }
      end,
      row("Temas prioritários", :text, nil, info: "Temas com mais projetos de lei apresentados.") do |d|
        { value: profiles[d.id].top_themes.map(&:first).join(", ").presence }
      end,
      row("Candidato à reeleição", :text, nil) { |d| { value: reelection_ids.include?(d.id) ? "Sim" : "Não" } },
      row("Escolaridade", :text, nil) { |d| { value: d.education_level.presence } }
    ]
  end

  # :best / :worst quando a linha tem direção e os valores não são todos iguais
  def highlight(row, deputy)
    return unless row.better

    numbers = row.values.values.filter_map { |cell| cell[:value] }
    value = row.values.dig(deputy.id, :value)
    return if value.nil? || numbers.size < 2 || numbers.uniq.size < 2

    best, worst = row.better == :higher ? [numbers.max, numbers.min] : [numbers.min, numbers.max]
    return :best if value == best

    :worst if value == worst
  end

  # [[deputado A, deputado B, { common:, different:, pct: }]]
  def divergences
    deputies.combination(2).map { |a, b| [a, b, DeputyMetrics.divergence(a, b)] }
  end

  private

  def row(label, format, better, info: nil)
    Row.new(label: label, format: format, better: better, info: info,
            values: deputies.to_h { |deputy| [deputy.id, yield(deputy)] })
  end

  def expenses = @expenses ||= DeputyMetrics.expenses(year)
  def participation = @participation ||= DeputyMetrics.participation
  def alignment = @alignment ||= DeputyMetrics.alignment
  def bill_counts = @bill_counts ||= Bill.where(deputy_id: deputies.map(&:id)).group(:deputy_id).count
  def reelection_ids = @reelection_ids ||= Deputy.running_for_reelection.where(id: deputies.map(&:id)).pluck(:id)
  def profiles = @profiles ||= deputies.to_h { |deputy| [deputy.id, DeputyThemeProfile.new(deputy)] }
end
