# Ranking de todos os partidos com bancada por um indicador, com os mesmos
# números da página de comparação de partidos (PartyComparison).
#
# Responde perguntas sobre o conjunto dos partidos ("quais têm mais deputados?",
# "qual é o mais coeso?") sem a IA precisar consultar partido por partido.
class PartyRankingTool < ApplicationTool
  MAX_LIMIT = 30

  # Critério de cada indicador, para a IA explicar o que o número significa
  CRITERIA = {
    "seats" => "deputados federais em exercício na Câmara dos Deputados (513 cadeiras no total).",
    "states" => "número de estados com ao menos um deputado do partido.",
    "governism" => "% das votações com orientação Sim/Não do Governo em que a maioria da bancada votou " \
                   "igual ao Governo (só partidos com ao menos #{PartyComparison::MIN_GOVERNMENT_POLLS} votações). " \
                   "Bloco: governista (90% ou mais), centro (50% a 89%) ou oposição (menos de 50%).",
    "cohesion" => "coesão da bancada pelo índice de Rice: 100% significa que todos os deputados votaram igual em " \
                  "todas as votações; quanto menor, mais a bancada se divide.",
    "adherence" => "% das votações com orientação da liderança do partido em que a maioria da bancada seguiu o líder.",
    "participation" => "média da participação dos deputados da bancada nas votações nominais " \
                       "do período em que exerceram o mandato.",
    "expenses" => "média do gasto mensal da cota parlamentar (CEAP) por deputado da bancada, em reais.",
    "bills" => "projetos de lei do partido divididos pelo número de deputados da bancada.",
    "women" => "% de mulheres entre os candidatos do partido a deputado federal em 2026."
  }.freeze

  UNITS = {
    "seats" => "deputados", "states" => "estados", "governism" => "%", "cohesion" => "%", "adherence" => "%",
    "participation" => "%", "expenses" => "R$ por mês", "bills" => "projetos por deputado", "women" => "%"
  }.freeze

  description <<~DESC
    Ranking de todos os partidos com bancada na Câmara por um indicador:
    #{CRITERIA.keys.map { |key| "#{key} (#{PartyComparison::SORTS[key][:label]})" }.join(', ')}.
    Use para perguntas sobre o conjunto dos partidos, como "quais partidos têm
    mais deputados?", "qual é o mais governista?" ou "qual gasta menos?".
  DESC

  param :criterion, desc: "Indicador do ranking: #{CRITERIA.keys.join(', ')}"
  param :order, desc: "desc (do maior para o menor, padrão) ou asc (do menor para o maior)", required: false
  param :limit, type: "integer", desc: "Quantidade de partidos (padrão #{LIST_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(criterion:, order: nil, limit: nil)
    return { erro: "Critério inválido. Use um destes: #{CRITERIA.keys.join(', ')}." } unless CRITERIA.key?(criterion)

    direction = order.to_s == "asc" ? :asc : :desc
    comparison = PartyComparison.new
    value = PartyComparison::SORTS[criterion][:value]
    present, missing = comparison.sorted_rows(criterion, direction).partition { |row| row.public_send(value) }

    {
      criterio: PartyComparison::SORTS[criterion][:label],
      como_e_calculado: CRITERIA[criterion],
      unidade: UNITS[criterion],
      ano_dos_gastos: (comparison.year if criterion == "expenses"),
      ordem: direction == :desc ? "do maior para o menor" : "do menor para o maior",
      total_de_partidos: comparison.rows.size,
      total_de_cadeiras: comparison.total_seats,
      ranking: present.first(limit_for(limit)).each_with_index.map { |row, index| ranking_row(row, value, index) },
      partidos_sem_dados: missing.map(&:label),
      pagina: routes.compare_parties_path(sort: criterion, dir: direction, anchor: "indicadores")
    }.compact
  end

  private

  def limit_for(limit)
    limit.to_i.positive? ? [limit.to_i, MAX_LIMIT].min : LIST_LIMIT
  end

  def ranking_row(row, value, index)
    {
      posicao: index + 1,
      party_id: row.party.id,
      sigla: row.label,
      nome: row.party.name,
      valor: value == :monthly ? money(row.monthly) : row.public_send(value),
      cadeiras: row.seats,
      bloco: PartyComparison::BLOCS.dig(row.bloc, :label)
    }.compact
  end
end
