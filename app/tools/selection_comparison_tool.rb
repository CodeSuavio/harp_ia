# Comparação lado a lado de partidos ou deputados escolhidos, com a mesma
# tabela e os mesmos pares "como votaram entre si" das páginas de comparação
# por seleção (PartySelectionComparison e DeputyComparison, que têm o mesmo
# formato de linhas).
#
# A consulta aceita mais registros que as páginas (LIMIT): os limites delas
# são de espaço na tela, não das contas. Assim a Harpia responde "quais dois
# votam mais parecido entre esses cinco?" sem pedir que o usuário reduza a
# lista; o link para a página só entra quando o conjunto cabe nela.
#
# Atenção ao significado dos pares: entre partidos, a página mostra em quantas
# votações as maiorias votaram IGUAL (afinidade); entre deputados, em quantas
# votaram DIFERENTE (divergência). Os campos levam isso no nome.
class SelectionComparisonTool < ApplicationTool
  KINDS = %w[partidos deputados].freeze
  UNITS = { currency: "R$", percent: "%", decimal: "", integer: "", text: "" }.freeze
  # Registros por consulta
  LIMIT = 10
  # Acima disso, os pares vão resumidos: os mais parecidos e os mais diferentes
  PAIRS_LIMIT = 10
  PAIRS_SUMMARY = 5

  description <<~DESC
    Compara lado a lado de 2 a #{LIMIT} partidos ou deputados escolhidos, com a
    mesma tabela (melhor e pior de cada linha) e os mesmos pares "como votaram
    entre si" das páginas de comparação por seleção, do par mais parecido ao
    mais diferente. Use para comparar registros escolhidos ou já citados na
    conversa ("compare PT e PL", "quem gasta menos entre esses deputados?",
    "quais dois votam mais parecido?").
    Partidos: sigla ou party_id. Deputados: deputy_id (use search_platform para achar).
  DESC

  param :kind, desc: "partidos ou deputados"
  param :ids, desc: "Separados por vírgula: siglas ou party_id (partidos) ou deputy_id (deputados), " \
                    "ex.: \"PT, PL\" ou \"687, 887\""

  def execute(kind:, ids:)
    return { erro: "Tipo inválido. Use partidos ou deputados." } unless KINDS.include?(kind)

    tokens = ids.to_s.split(/[,;]/).map(&:strip).compact_blank.uniq
    kind == "partidos" ? parties(tokens) : deputies(tokens)
  end

  private

  # ----- PARTIDOS -----

  def parties(tokens)
    found, missing = resolve(tokens) { |token| party_for(token)&.id }
    selection = PartySelectionComparison.for(found, limit: LIMIT)
    # Partidos sem deputados em exercício não entram na tabela da página
    missing += found.first(LIMIT).map(&:to_s) - selection.parties.map { |row| row.party.id.to_s }
    entities = selection.parties.map do |row|
      cite_party(row.party)
      entity(row.party.id, row.label, row.party.name, bloco: selection.bloc_label(row.bloc))
    end
    pairs = selection.affinities.map { |a, b, cell| affinity_pair(a, b, cell) }

    result(entities, selection, PartySelectionComparison, found, missing, votes(pairs, :votaram_igual_pct, :desc)) do
      [link("Ver comparação dos partidos", routes.compare_parties_path(ids: entities.pluck(:id))),
       *selection.parties.map { |row| link("Ver página do #{row.label}", routes.party_path(row.party)) }]
    end
  end

  # Pelo party_id ou pela sigla, sem diferenciar acentos ("uniao" → UNIÃO)
  def party_for(token)
    return Party.find_by(id: token) if token.match?(/\A\d+\z/)

    find_party(token) || Party.all.find { |party| normalize(party.label) == normalize(token) }
  end

  def affinity_pair(party_a, party_b, cell)
    pair = { partidos: "#{party_a.label} e #{party_b.label}" }
    return pair.merge(aviso: "poucas votações em comum para comparar") unless cell

    pair.merge(votaram_igual_pct: cell[:pct], votacoes_iguais: cell[:same], votacoes_em_comum: cell[:common])
  end

  # ----- DEPUTADOS -----

  def deputies(tokens)
    found, missing = resolve(tokens) { |token| token.to_i if token.match?(/\A\d+\z/) && Deputy.exists?(token.to_i) }
    comparison = DeputyComparison.for(found, limit: LIMIT)
    entities = comparison.deputies.map do |deputy|
      cite_deputy(deputy)
      entity(deputy.id, deputy.name, nil, partido: party_label(deputy), uf: deputy.state_label)
    end
    pairs = comparison.divergences.map { |a, b, divergence| divergence_pair(a, b, divergence) }

    result(entities, comparison, DeputyComparison, found, missing, votes(pairs, :votaram_diferente_pct, :asc)) do
      [link("Ver comparação dos deputados", routes.compare_deputies_path(ids: entities.pluck(:id))),
       *comparison.deputies.map { |deputy| link("Ver perfil de #{deputy.name}", routes.deputy_path(deputy)) }]
    end
  end

  def divergence_pair(deputy_a, deputy_b, divergence)
    pair = { deputados: "#{deputy_a.name} e #{deputy_b.name}" }
    return pair.merge(aviso: "não têm votações em comum registradas") unless divergence[:common].positive?

    pair.merge(votaram_diferente_pct: divergence[:pct], votacoes_diferentes: divergence[:different],
               votacoes_em_comum: divergence[:common])
  end

  # ----- COMUM -----

  # [ids encontrados, termos não encontrados], na ordem em que vieram
  def resolve(tokens)
    found = tokens.map { |token| [token, yield(token)] }
    [found.filter_map(&:last).uniq, found.reject(&:last).map(&:first)]
  end

  def entity(id, name, full_name, **extra)
    { id: id, nome: name, nome_completo: full_name, **extra }.compact
  end

  # Pares do mais parecido ao mais diferente (key: o percentual do par;
  # direction: :desc quando mais é mais parecido), os sem dados no fim. Com
  # muitos pares, só os mais parecidos e os mais diferentes.
  def votes(pairs, key, direction)
    with_data, without = pairs.partition { |pair| pair[key] }
    sorted = with_data.sort_by { |pair| [direction == :desc ? -pair[key] : pair[key], -pair[:votacoes_em_comum]] }
    return { ordem: "do par mais parecido ao mais diferente", pares: sorted + without } if pairs.size <= PAIRS_LIMIT

    { total_de_pares: pairs.size, mais_parecidos: sorted.first(PAIRS_SUMMARY),
      mais_diferentes: sorted.last(PAIRS_SUMMARY).reverse, pares_sem_dados: without.size.nonzero? }.compact
  end

  # Mesma tabela e mesmos pares da página; erro com menos de 2 registros. Os
  # links só quando o conjunto cabe na página (service::LIMIT)
  def result(entities, comparison, service, found, missing, votes) # rubocop:disable Metrics/ParameterLists
    if entities.size < 2
      return { erro: "A comparação precisa de ao menos 2 registros encontrados.",
               nao_encontrados: missing.presence }.compact
    end

    {
      escolhidos: entities,
      como_ler: service::SECTIONS["table"][:reading],
      linhas: comparison.rows.map { |row| line(row, entities, comparison) },
      como_votaram_entre_si: { como_e_calculado: service::SECTIONS["votes"][:how], **votes },
      nao_encontrados: missing.presence,
      aviso: (limit_notice if found.size > LIMIT),
      acoes: (yield if entities.size <= service::LIMIT)
    }.compact
  end

  def limit_notice = "A consulta compara até #{LIMIT}; ficaram os #{LIMIT} primeiros."

  # Uma linha da tabela: valor de cada registro e, nas linhas com direção, o
  # melhor e o pior, como a página marca (highlight)
  def line(row, entities, comparison)
    marks = entities.to_h { |entity| [entity[:id], comparison.highlight(row, highlight_key(comparison, entity[:id]))] }
    {
      indicador: row.label,
      como_e_calculado: row.info,
      unidade: UNITS[row.format].presence,
      conta_como_melhor: { higher: "o maior valor", lower: "o menor valor" }[row.better],
      valores: entities.map { |entity| cell(row, entity) },
      melhor: entities.find { |entity| marks[entity[:id]] == :best }&.dig(:nome),
      pior: entities.find { |entity| marks[entity[:id]] == :worst }&.dig(:nome)
    }.compact
  end

  def cell(row, entity)
    value = row.values.dig(entity[:id], :value)
    { nome: entity[:nome], valor: row.format == :currency ? money(value) : value,
      detalhe: row.values.dig(entity[:id], :detail) }.compact
  end

  # highlight recebe a linha do partido (PartyComparison::Row) ou o deputado
  def highlight_key(comparison, id)
    if comparison.is_a?(PartySelectionComparison)
      comparison.parties.find { |row| row.party.id == id }
    else
      comparison.deputies.find { |deputy| deputy.id == id }
    end
  end
end
