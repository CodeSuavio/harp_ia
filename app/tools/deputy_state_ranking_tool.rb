# Deputados federais vistos por estado (UF), em dois modos:
# - sem indicador: quantos deputados cada estado tem (bancada de cada UF);
# - com indicador: o deputado no topo do indicador em cada estado
#   (quem mais gastou, quem mais apresentou projetos etc.).
#
# Os indicadores e os números são os mesmos do DeputyRankingTool. Não há
# página com estes rankings: a continuação é só "Ver mais", pela Harpia.
class DeputyStateRankingTool < ApplicationTool
  CRITERIA = DeputyRankingTool::CRITERIA
  STATES_LIMIT = 27

  description <<~DESC
    Deputados federais por estado (UF). Sem criterion, conta quantos deputados
    cada estado tem ("quantos deputados cada estado tem?", "qual estado tem a
    maior bancada?"). Com criterion, traz o deputado no topo do indicador em
    cada estado ("quem mais gastou em cada estado?", "quem mais apresentou
    projetos em cada estado?"). Indicadores:
    #{CRITERIA.map { |key, row| "#{key} (#{row[:label]})" }.join(', ')}.
    Para um ranking de um único estado, use deputy_ranking com o filtro state.
  DESC

  param :criterion, desc: "Indicador (opcional): #{CRITERIA.keys.join(', ')}. Sem ele, conta os deputados por estado",
                    required: false
  param :order, desc: "desc (do maior para o menor, padrão) ou asc (do menor para o maior)", required: false
  param :year, type: "integer", desc: "Ano dos gastos (opcional; padrão: ano mais recente com dados)", required: false
  param :limit, type: "integer", desc: "Quantidade de estados (padrão #{RANKING_LIMIT}, máximo #{STATES_LIMIT})",
                required: false

  def execute(criterion: nil, order: nil, year: nil, limit: nil)
    criterion = criterion.presence
    if criterion && !CRITERIA.key?(criterion)
      return { erro: "Critério inválido. Use um destes: #{CRITERIA.keys.join(', ')}." }
    end

    direction = order.to_s == "asc" ? :asc : :desc
    limit = ranking_limit(limit, STATES_LIMIT)
    criterion ? leaders(criterion, direction, DeputyRankingTool.expense_year(year), limit) : counts(direction, limit)
  end

  private

  def counts(direction, limit)
    counts = Deputy.group(:state_label).count
    total = counts.values.sum
    sorted = counts.sort_by { |uf, count| [direction == :desc ? -count : count, uf] }

    {
      agrupado_por: "Estado (UF)",
      como_e_calculado: "número de deputados federais em exercício na base do Harp_IA, por estado (UF).",
      unidade: "deputados",
      ordem: order_label(direction),
      total_de_deputados: total,
      ranking: sorted.first(limit).each_with_index.map do |(uf, count), index|
        { posicao: index + 1, uf: uf, deputados: count, percentual: (count * 100.0 / total).round(1) }
      end
    }.merge(partial(sorted.size, limit, "número de deputados por estado, #{order_label(direction)}",
                    sorted.first(limit).last&.first)).compact
  end

  # Em cada estado, o deputado com o maior (ou menor) valor do indicador
  def leaders(criterion, direction, year, limit)
    values = DeputyRankingTool.values_for(criterion, year)
    by_state = Deputy.includes(:party).select { |deputy| values[deputy.id] }.group_by(&:state_label)
    sorted = leaders_by_state(by_state, values, direction)

    {
      criterio: CRITERIA[criterion][:label],
      como_e_calculado: CRITERIA[criterion][:criterio],
      unidade: CRITERIA[criterion][:unidade],
      ano_dos_gastos: (year if criterion.start_with?("expenses")),
      ordem: order_label(direction),
      estados: sorted.first(limit).each_with_index.map do |deputy, index|
        leader_row(deputy, values, criterion, index)
      end
    }.merge(partial(sorted.size, limit, leaders_description(criterion, direction, year),
                    sorted.first(limit).last&.name)).compact
  end

  # O deputado no topo de cada estado, ordenados pelo valor
  def leaders_by_state(by_state, values, direction)
    pick = direction == :desc ? :max_by : :min_by
    leaders = by_state.transform_values { |deputies| deputies.public_send(pick) { |deputy| values[deputy.id] } }
    leaders.values.sort_by { |deputy| direction == :desc ? -values[deputy.id] : values[deputy.id] }
  end

  # Recorte e "Ver mais" (não há página com estes rankings)
  def partial(total, limit, description, last)
    shown = [limit, total].min
    { recorte: recorte(shown, total),
      acoes: continuation(shown: shown, total: total, max: STATES_LIMIT, description: description, last: last) }
  end

  def leader_row(deputy, values, criterion, index)
    cite_deputy(deputy)
    value = values[deputy.id]
    { posicao: index + 1, uf: deputy.state_label, deputy_id: deputy.id, nome: deputy.name,
      partido: party_label(deputy), valor: criterion.start_with?("expenses") ? money(value) : value }
  end

  # "deputado com o maior valor de gasto mensal em cada estado, do maior para o menor, gastos de 2025"
  def leaders_description(criterion, direction, year)
    [
      "deputado com o #{direction == :desc ? 'maior' : 'menor'} valor de " \
      "#{CRITERIA[criterion][:label].downcase} em cada estado",
      order_label(direction), ("gastos de #{year}" if criterion.start_with?("expenses"))
    ].compact.join(", ")
  end
end
