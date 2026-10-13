# Deputados com alertas de gastos, com os mesmos números e filtros da página
# de alertas (ExpenseAlertRanking): ano, estado, partido e gravidade mínima.
#
# Responde perguntas como "algum alerta de gravidade alta em SP em 2025?" ou
# "quem tem mais alertas de gastos no PL?" sem a IA precisar consultar
# deputado por deputado. Alertas não são prova de irregularidade.
class ExpenseAlertRankingTool < ApplicationTool
  MAX_LIMIT = 20
  SEVERITIES = { "low" => "todas as gravidades", "medium" => "gravidade média ou alta",
                 "high" => "gravidade alta" }.freeze
  SEVERITY_NAMES = { low: "baixa", medium: "média", high: "alta" }.freeze

  description <<~DESC
    Deputados com alertas de gastos da cota parlamentar (valores fora do padrão
    segundo critérios estatísticos), ordenados pela pontuação dos alertas, com
    filtros por ano, estado (UF), partido e gravidade mínima. São os mesmos
    alertas da página de alertas. Use para perguntas como "algum alerta de
    gravidade máxima em SP em 2025?" ou "quem tem mais alertas de gastos?".
    Para os alertas de um único deputado, use deputy_details.
  DESC

  param :severity, desc: "Gravidade mínima: low (todas, padrão), medium (média e alta) ou high " \
                         "(só alta, a gravidade máxima)", required: false
  param :state, desc: "UF para filtrar, ex.: SP (opcional)", required: false
  param :party, desc: "Sigla do partido para filtrar, ex.: PT (opcional)", required: false
  param :year, type: "integer", desc: "Ano dos gastos (opcional; padrão: ano mais recente com dados)", required: false
  param :order, desc: "score (pontuação dos alertas, padrão) ou share (% do gasto em notas com alerta)",
                required: false
  param :limit, type: "integer", desc: "Quantidade de deputados (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(severity: nil, state: nil, party: nil, year: nil, order: nil, limit: nil) # rubocop:disable Metrics/ParameterLists
    party_record = Party.find_by("label ILIKE ?", party.to_s.strip) if party.present?
    return not_found("Partido") if party.present? && !party_record

    filters = { severity: SEVERITIES.key?(severity) ? severity : "low", state: state.presence&.upcase,
                party: party_record, year: DeputyRankingTool.expense_year(year),
                order: order.to_s == "share" ? "share" : "score" }
    ranking = ExpenseAlertRanking.new(**filters)

    # Sem alertas gravados para o ano, não dá para dizer que não houve alertas
    return not_computed(filters[:year]) unless ranking.computed_at

    result(ranking, filters, ranking_limit(limit, MAX_LIMIT))
  end

  private

  def result(ranking, filters, limit)
    rows = ranking.rows
    shown = rows.first(limit)
    deputies = Deputy.includes(:party).where(id: shown.pluck(:deputy_id)).index_by(&:id)

    {
      filtros: filters_text(filters),
      ano: filters[:year],
      como_e_calculado: "pontuação = soma dos alertas do deputado no recorte, com peso pela gravidade " \
                        "(alta #{ExpenseAlert::WEIGHTS['high']}, média #{ExpenseAlert::WEIGHTS['medium']}, " \
                        "baixa #{ExpenseAlert::WEIGHTS['low']}); empate decidido pelo valor sinalizado.",
      ordem: filters[:order] == "share" ? "% do gasto do ano em notas com alerta" : "pontuação dos alertas",
      deputados_com_alertas: rows.size,
      total_de_alertas: rows.sum { |row| row[:count] },
      ranking: shown.each_with_index.map { |row, index| ranking_row(row, deputies[row[:deputy_id]], index) },
      recorte: recorte(shown.size, rows.size),
      observacao: "Alertas indicam gastos fora do padrão segundo critérios estatísticos; " \
                  "não são prova de irregularidade.",
      acoes: next_steps(rows, shown, deputies, filters)
    }.compact
  end

  def ranking_row(row, deputy, index)
    {
      posicao: index + 1, deputy_id: deputy.id, nome: deputy.name, partido: party_label(deputy),
      uf: deputy.state_label, alertas: row[:count], pontuacao: row[:score],
      por_gravidade: SEVERITY_NAMES.to_h { |key, name| [name, row[key].to_i] }.select { |_, count| count.positive? },
      valor_em_notas_com_alerta: money(row[:flagged]), percentual_do_gasto_do_ano: row[:share]&.to_f
    }.compact
  end

  # Continuação da lista (página de alertas com os mesmos filtros) e as notas
  # com alerta do primeiro deputado. Sem alertas no recorte, a mesma consulta
  # com todas as gravidades.
  def next_steps(rows, shown, deputies, filters)
    return any_severity(filters) if rows.empty?

    first = deputies[shown.first[:deputy_id]]
    [
      *continuation(shown: shown.size, total: rows.size, max: MAX_LIMIT,
                    description: "deputados com alertas de gastos, #{filters_text(filters)}",
                    page: page_path(filters)),
      link("Ver notas com alerta de #{first.name}",
           routes.deputy_path(first, tab: "expenses", year: filters[:year], alerts: "1"))
    ]
  end

  def any_severity(filters)
    return if filters[:severity] == "low"

    text = filters_text(filters.merge(severity: "low"))
    [question("Alertas de qualquer gravidade", "Quais deputados têm alertas de gastos, #{text}?")]
  end

  # "gravidade alta, em SP, do PL, em 2025"
  def filters_text(filters)
    [SEVERITIES[filters[:severity]], ("em #{filters[:state]}" if filters[:state]),
     ("do #{filters[:party].label}" if filters[:party]), "em #{filters[:year]}",
     ("por % do gasto em notas com alerta" if filters[:order] == "share")].compact.join(", ")
  end

  # Página de alertas com os mesmos filtros (mesmos parâmetros de ExpenseAlertsController)
  def page_path(filters)
    routes.expense_alerts_path({ year: filters[:year], state: filters[:state], party: filters[:party]&.id,
                                 severity: (filters[:severity] unless filters[:severity] == "low"),
                                 order: (filters[:order] unless filters[:order] == "score") }.compact)
  end

  def not_computed(year)
    { ano: year, alertas_calculados: false,
      observacao: "Os alertas de gastos de #{year} ainda não foram calculados na plataforma (são atualizados " \
                  "todos os dias). Não é possível dizer se houve ou não alertas nesse recorte." }
  end
end
