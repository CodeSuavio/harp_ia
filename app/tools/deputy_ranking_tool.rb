# Ranking dos deputados por um indicador, com os mesmos cálculos da listagem
# de deputados (DeputyMetrics), opcionalmente filtrado por estado e partido.
#
# Responde perguntas como "quem mais gastou?" ou "quem mais falta às votações
# em SP?" sem a IA precisar consultar deputado por deputado.
class DeputyRankingTool < ApplicationTool # rubocop:disable Metrics/ClassLength -- indicadores, ranking e link da lista
  MAX_LIMIT = 20

  CRITERIA = {
    "expenses" => { unidade: "R$ por mês", label: "Gasto mensal",
                    criterio: "média do gasto mensal da cota parlamentar (CEAP) no ano, em reais: total gasto " \
                              "dividido pelos meses com despesa." },
    "expenses_total" => { unidade: "R$", label: "Gasto total no ano",
                          criterio: "total gasto da cota parlamentar (CEAP) no ano, em reais." },
    "participation" => { unidade: "%", label: "Participação nas votações",
                         criterio: "% das votações nominais do período de mandato do deputado em que ele votou. " \
                                   "O período vai do primeiro ao último voto, para não penalizar suplentes." },
    "alignment" => { unidade: "%", label: "Alinhamento com o partido",
                     criterio: "% das votações em que o deputado votou como a maioria do próprio partido " \
                               "(maioria calculada sem o voto dele; empates não contam)." },
    "against_party" => { unidade: "votações", label: "Votos contra o partido",
                         criterio: "número de votações em que o deputado votou contra a maioria do próprio partido." },
    "bills" => { unidade: "projetos", label: "Projetos de lei",
                 criterio: "projetos de lei de autoria ou coautoria do deputado." }
  }.freeze

  description <<~DESC
    Ranking dos deputados federais por um indicador:
    #{CRITERIA.map { |key, row| "#{key} (#{row[:label]})" }.join(', ')}.
    Pode filtrar por estado (UF) e partido (sigla). Use para perguntas sobre o
    conjunto dos deputados, como "quem mais gastou?", "quem mais falta às
    votações?" ou "quem mais vota contra o partido no PT?". Com bills, pode
    filtrar por tema ("quem tem mais projetos sobre saúde?"); para mais de um
    tema, consulte um tema por vez.
  DESC

  param :criterion, desc: "Indicador do ranking: #{CRITERIA.keys.join(', ')}"
  param :order, desc: "desc (do maior para o menor, padrão) ou asc (do menor para o maior)", required: false
  param :state, desc: "UF para filtrar, ex.: SP (opcional)", required: false
  param :party, desc: "Sigla do partido para filtrar, ex.: PT (opcional)", required: false
  param :year, type: "integer", desc: "Ano dos gastos (opcional; padrão: ano mais recente com dados)", required: false
  param :theme, desc: "Nome do tema, só com o indicador bills, ex.: Saúde, Educação (opcional)", required: false
  param :limit, type: "integer", desc: "Quantidade de deputados (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  # Também usados pelo DeputyStateRankingTool, para os mesmos números nos dois rankings
  def self.expense_year(year)
    years = Expense.distinct.pluck(:year)
    years.include?(year.to_i) ? year.to_i : years.max
  end

  # { deputy_id => valor }
  def self.values_for(criterion, year)
    case criterion
    when "expenses" then DeputyMetrics.expenses(year).transform_values { |row| row[:monthly] }
    when "expenses_total" then DeputyMetrics.expenses(year).transform_values { |row| row[:total] }
    when "participation" then DeputyMetrics.participation.transform_values { |row| row[:pct] }
    when "alignment" then DeputyMetrics.alignment.transform_values { |row| row[:pct] }
    when "against_party" then DeputyMetrics.alignment.transform_values { |row| row[:against] }
    when "bills" then Deputy.pluck(:id, Arel.sql(DeputiesController::BILLS_COUNT_SQL)).to_h
    end
  end

  # { deputy_id => projetos de autoria ou coautoria no tema }, com zero para quem
  # não tem nenhum (a mesma contagem da aba Projetos do deputado filtrada pelo tema)
  def self.bills_in_theme(theme)
    Deputy.pluck(:id).index_with(0).merge(Bill.count_by_author(Deputy.select(:id), theme: theme))
  end

  def execute(criterion:, order: nil, state: nil, party: nil, year: nil, theme: nil, limit: nil) # rubocop:disable Metrics/ParameterLists
    return { erro: "Critério inválido. Use um destes: #{CRITERIA.keys.join(', ')}." } unless CRITERIA.key?(criterion)
    return { erro: "O filtro de tema só vale para o indicador bills." } if theme.present? && criterion != "bills"

    error = lookup_error(theme, party)
    return error if error

    @theme = find_theme(theme)
    direction = order.to_s == "asc" ? :asc : :desc
    result(criterion, direction, state.presence&.upcase, find_party(party), self.class.expense_year(year),
           ranking_limit(limit, MAX_LIMIT))
  end

  private

  def result(criterion, direction, state, party, year, limit) # rubocop:disable Metrics/ParameterLists
    deputies = filtered(state, party).to_a
    values = @theme ? self.class.bills_in_theme(@theme) : self.class.values_for(criterion, year)
    ranked, missing = deputies.partition { |deputy| values[deputy.id] }
    rows = ranking(ranked, values, criterion, direction, limit)

    {
      criterio: CRITERIA[criterion][:label],
      como_e_calculado: calculation(criterion),
      unidade: CRITERIA[criterion][:unidade],
      ano_dos_gastos: (year if criterion.start_with?("expenses")),
      ordem: order_label(direction),
      filtros: { uf: state, partido: party&.label, tema: @theme&.name }.compact.presence,
      total_de_deputados: deputies.size,
      deputados_sem_dados: missing.size,
      ranking: rows,
      recorte: recorte(rows.size, ranked.size),
      acoes: next_steps(rows, ranked.size, criterion, direction, state, party, year)
    }.compact
  end

  def calculation(criterion)
    return CRITERIA[criterion][:criterio] unless @theme

    "projetos de lei de autoria ou coautoria do deputado classificados no tema #{@theme.name} " \
      "(um projeto pode estar em mais de um tema)."
  end

  # Continuação do ranking. A listagem de deputados não filtra por tema: com
  # tema, a continuação é só pela Harpia, e os projetos do primeiro deputado
  # no tema entram como página relacionada.
  def next_steps(rows, total, criterion, direction, state, party, year) # rubocop:disable Metrics/ParameterLists
    steps = continuation(shown: rows.size, total: total, max: MAX_LIMIT,
                         description: ranking_description(criterion, direction, state, party, year),
                         page: (page_path(criterion, direction, state, party, year) unless @theme))
    return steps unless @theme && rows.any?

    first = rows.first
    [*steps, link("Ver projetos de #{first[:nome]} sobre #{@theme.name}",
                  routes.deputy_path(first[:deputy_id], tab: "bills", theme: @theme.slug))]
  end

  def filtered(state, party)
    scope = Deputy.includes(:party)
    scope = scope.where(state_label: state) if state
    scope = scope.where(party: party) if party
    scope
  end

  def ranking(deputies, values, criterion, direction, limit)
    sorted = deputies.sort_by { |deputy| [direction == :desc ? -values[deputy.id] : values[deputy.id], deputy.name] }
    sorted.first(limit).each_with_index.map do |deputy, index|
      ranking_row(deputy, values[deputy.id], criterion, index)
    end
  end

  def ranking_row(deputy, value, criterion, index)
    row = { posicao: index + 1, deputy_id: deputy.id, nome: deputy.name, partido: party_label(deputy),
            uf: deputy.state_label, valor: criterion.start_with?("expenses") ? money(value) : value }
    # Contexto do percentual, para a IA não tratar 2 de 2 votações como 100% de assiduidade
    if criterion == "participation"
      participation = DeputyMetrics.participation[deputy.id]
      row.merge!(votou: participation[:voted], votacoes_no_periodo: participation[:total])
    end
    row
  end

  # "deputados por gasto mensal, do maior para o menor, em SP, do PT, gastos de 2025"
  def ranking_description(criterion, direction, state, party, year)
    parts = ["deputados por #{CRITERIA[criterion][:label].downcase}#{" sobre #{@theme.name}" if @theme}",
             order_label(direction), ("em #{state}" if state),
             ("do #{party.label}" if party), ("gastos de #{year}" if criterion.start_with?("expenses"))]
    parts.compact.join(", ")
  end

  # Listagem de deputados com a mesma ordenação, direção, filtros e ano do
  # ranking: a página mostra a lista completa, com o valor de cada deputado
  # (DeputiesController::SORTS usa os mesmos indicadores)
  def page_path(criterion, direction, state, party, year)
    year = nil if year == DeputyMetrics.reference_year || !criterion.start_with?("expenses")
    routes.deputies_path({ sort: criterion, dir: (direction if direction == :asc), state: state,
                           party: party&.id, year: year }.compact)
  end
end
