# Dados dos gráficos e da tabela do panorama de deputados, com os mesmos
# cálculos da página (DeputyPanorama), seção por seção.
#
# Como na página, blocos, mapa e destaques mostram sempre a Câmara inteira;
# os filtros de estado e partido valem para a tabela (quantos deputados, as
# médias e quem mais segue o Governo) e, no mapa, só para listar os pontos de
# um recorte. Rankings por gasto, participação, alinhamento, votos contra o
# partido e projetos ficam com deputy_ranking, que usa os mesmos números.
class DeputyPanoramaTool < ApplicationTool
  SECTIONS = %w[insights blocs positioning indicators].freeze
  # Deputados de um bloco diferente do partido e pontos do mapa listados por consulta
  LIST_LIMIT = 30
  POINTS_LIMIT = 20
  MAX_LIMIT = 20

  description <<~DESC
    Dados dos gráficos e da tabela do panorama de deputados (/deputies/compare),
    iguais aos da página. Vale também sem página informada (ex.: no chat
    principal), quando o usuário citar um desses gráficos. Uma seção por consulta:
    #{SECTIONS.map { |key| "- #{key} (#{DeputyPanorama::SECTIONS[key][:title]}): #{DeputyPanorama::SECTIONS[key][:chart]}" }.join("\n")}
    Blocos, mapa e destaques mostram a Câmara inteira, como a página. state e
    party filtram indicators (quantos deputados aparecem, médias e ranking de
    governismo) e, em positioning, listam os pontos do recorte. Para rankings por
    gasto, participação, alinhamento, votos contra o partido e projetos, use
    deputy_ranking.
  DESC

  param :section, desc: "Seção da página: #{SECTIONS.join(', ')}"
  param :state, desc: "UF para filtrar, ex.: SP (opcional; indicators e positioning)", required: false
  param :party, desc: "Sigla do partido para filtrar, ex.: PL (opcional; indicators e positioning)", required: false
  param :order, desc: "indicators: desc (mais governistas primeiro, padrão) ou asc", required: false
  param :limit, type: "integer",
                desc: "indicators: quantidade de deputados (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(section:, state: nil, party: nil, order: nil, limit: nil)
    return { erro: "Seção inválida. Use uma destas: #{SECTIONS.join(', ')}." } unless SECTIONS.include?(section)
    return not_found("Partido") if party.present? && !find_party(party)

    @state = state.presence&.upcase
    return { erro: "UF não encontrada: #{state}." } if @state && !states.include?(@state)

    @party = find_party(party)
    @direction = order.to_s == "asc" ? :asc : :desc
    @limit = ranking_limit(limit, MAX_LIMIT)
    info = DeputyPanorama::SECTIONS[section]
    {
      secao: info[:title],
      o_que_mostra: [info[:chart], info[:reading]].compact.join(". "),
      como_e_calculado: info[:how],
      **send(section),
      acoes: next_steps(section)
    }.compact
  end

  private

  def panorama
    @panorama ||= DeputyPanorama.new
  end

  def states = @states ||= Deputy.distinct.pluck(:state_label)

  def filtered? = @state || @party

  def filters = { uf: @state, partido: @party&.label }.compact.presence

  # Seções que a página não filtra: os filtros pedidos não mudam os números
  def unfiltered_notice
    "Esta seção mostra a Câmara inteira, como a página; os filtros não se aplicam a ela." if filtered?
  end

  def insights
    { aviso: unfiltered_notice,
      destaques: panorama.insights.map { |_icon, title, text| { titulo: title, texto: text } } }
  end

  def blocs
    blocs = panorama.blocs
    off_bloc = panorama.off_bloc.sort_by { |row, _| [row.party_label, row.name] }
    {
      aviso: unfiltered_notice,
      maioria_absoluta: DeputyPanorama::MAJORITY,
      total_de_deputados: panorama.total,
      blocos: DeputyPanorama::BLOCS.map { |key, bloc| bloc_row(bloc, blocs[key][:count]) },
      sem_dados: blocs[DeputyPanorama::NO_DATA][:count].nonzero?,
      fora_do_bloco_do_partido: {
        total: off_bloc.size,
        deputados: off_bloc.first(LIST_LIMIT).map { |row, party_bloc| off_bloc_row(row, party_bloc) },
        recorte: recorte([off_bloc.size, LIST_LIMIT].min, off_bloc.size)
      }.compact
    }
  end

  # Os 484 pontos não cabem numa resposta: o mapa vai resumido por bloco, e
  # a lista de pontos só sai para um recorte (estado ou partido)
  def positioning
    positioned = panorama.positioned
    return { aviso: "O mapa não é exibido: poucos deputados com votos registrados." } if positioned.size < 2

    by_bloc = positioned.group_by(&:bloc)
    {
      eixo_horizontal: "governismo (% de votações com orientação do Governo em que o deputado votou igual)",
      eixo_vertical: "alinhamento ao partido (% de votos iguais aos da maioria do próprio partido)",
      deputados_no_mapa: positioned.size,
      fora_do_mapa: panorama.total - positioned.size,
      por_bloco: DeputyPanorama::BLOCS.map { |key, bloc| bloc_summary(bloc, by_bloc[key].to_a) },
      recorte_do_mapa: (map_slice(positioned) if filtered?)
    }
  end

  def indicators
    rows = panorama.sorted_rows("governism", @direction, state: @state, party_id: @party&.id)
    ranked = rows.select(&:governism)
    shown = ranked.first(@limit)
    # para a continuação, em next_steps
    @ranking = { shown: shown.size, total: ranked.size, last: shown.last&.name }
    {
      filtros: filters,
      deputados_exibidos: rows.size,
      de: panorama.total,
      media_do_filtro: (averages(panorama.averages(rows)) if filtered? && rows.any?),
      media_da_camara: averages(panorama.averages),
      # Quem tem governismo calculado (o total do ranking) é menos que deputados_exibidos
      com_governismo_calculado: ranked.size,
      ranking_por_governismo: shown.each_with_index.map { |row, index| deputy_row(row).merge(posicao: index + 1) },
      ordem: order_label(@direction),
      recorte: recorte(shown.size, ranked.size)
    }
  end

  def bloc_row(bloc, count)
    { bloco: bloc[:label], criterio: bloc[:description], governismo_minimo_pct: bloc[:min], deputados: count }
  end

  def off_bloc_row(row, party_bloc)
    deputy_row(row).merge(bloco_da_maioria_do_partido: DeputyPanorama::BLOCS.dig(party_bloc, :label))
  end

  def bloc_summary(bloc, members)
    { bloco: bloc[:label], deputados: members.size, governismo_medio_pct: mean(members.map(&:governism_pct)),
      alinhamento_medio_pct: mean(members.map(&:alignment_pct)) }
  end

  # Pontos do recorte, do mais ao menos governista; a página mostra todos no mesmo mapa
  def map_slice(positioned)
    points = positioned.select { |row| in_filter?(row) }.sort_by { |row| [-row.governism_pct, row.name] }
    # no_mapa e fora_do_mapa dizem os totais; recorte só se refere à lista de deputados
    { filtros: filters, observacao: "Recorte do mapa; a página mostra todos os deputados no mesmo mapa.",
      no_mapa: points.size, fora_do_mapa: panorama.rows.count { |row| in_filter?(row) } - points.size,
      deputados: points.first(POINTS_LIMIT).map { |row| deputy_row(row).merge(alinhamento_pct: row.alignment_pct) },
      recorte: recorte([points.size, POINTS_LIMIT].min, points.size) }.compact
  end

  def in_filter?(row)
    (@state.nil? || row.state == @state) && (@party.nil? || row.deputy.party_id == @party.id)
  end

  def deputy_row(row)
    cite_deputy(row.deputy)
    { deputy_id: row.deputy.id, nome: row.name, partido: row.party_label, uf: row.state,
      bloco: DeputyPanorama::BLOCS.dig(row.bloc, :label), governismo_pct: row.governism_pct }.compact
  end

  # Médias da tabela (DeputyPanorama#averages), com as unidades da página
  def averages(values)
    {
      governismo_pct: values[:governism_pct]&.round, alinhamento_ao_partido_pct: values[:alignment_pct]&.round,
      votos_contra_o_partido: values[:against]&.round(1), participacao_pct: values[:participation_pct]&.round,
      gasto_mensal: money(values[:monthly]), projetos_de_lei: values[:bills]&.round(1),
      candidatos_a_reeleicao_pct: values[:reelection]
    }.compact
  end

  def mean(values)
    values = values.compact
    (values.sum.to_f / values.size).round unless values.empty?
  end

  # ----- PRÓXIMOS PASSOS -----

  def next_steps(section)
    case section
    when "indicators" then indicator_steps
    when "blocs" then [against_party_question, panorama_link]
    when "positioning"
      [question("Menos alinhados ao partido", "Quais deputados têm o menor alinhamento ao próprio partido?"),
       panorama_link]
    else [panorama_link]
    end
  end

  def against_party_question
    question("Quem mais vota contra o partido", "Quais deputados mais votam contra o próprio partido?")
  end

  # Continuação do ranking de governismo e a tabela com os mesmos filtros.
  # O ranking acompanha a contagem e as médias: a continuação só entra se a
  # IA mostrou a lista (não obrigatória)
  def indicator_steps
    description = ["deputados por governismo", order_label(@direction), ("em #{@state}" if @state),
                   ("do #{@party.label}" if @party)].compact.join(", ")
    continuation(shown: @ranking[:shown], total: @ranking[:total], max: MAX_LIMIT, description: description,
                 last: @ranking[:last], page: panorama_path(filters: true)) || [panorama_link(filters: true)]
  end

  # Ordenação padrão da página (governismo, do maior para o menor) fica fora
  # da URL, para o link ser reconhecido como a página em que o usuário já está
  def panorama_path(filters: false)
    params = filters ? { dir: (:asc if @direction == :asc), state: @state, party: @party&.id } : {}
    routes.compare_deputies_path(params.compact)
  end

  def panorama_link(filters: false)
    link("Ver panorama de deputados", panorama_path(filters: filters))
  end
end
