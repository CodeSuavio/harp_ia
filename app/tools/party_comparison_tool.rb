# Dados dos gráficos da página de comparação de partidos, com os mesmos
# cálculos da página (PartyComparison), seção por seção.
#
# Responde perguntas sobre um gráfico ("o que mostra o mapa de posicionamento?",
# "quais partidos formam o centro?") com os números que o usuário vê, sem a IA
# estimar a partir de rankings. A tabela de indicadores fica com party_ranking.
class PartyComparisonTool < ApplicationTool
  SECTIONS = %w[blocs positioning affinity insights].freeze

  description <<~DESC
    Dados dos gráficos da página de comparação de partidos (/parties/compare),
    iguais aos da página. Vale também sem página informada (ex.: no chat
    principal), quando o usuário citar um desses gráficos ou perguntar o que
    eles respondem. Uma seção por consulta:
    #{SECTIONS.map { |key| "- #{key} (#{PartyComparison::SECTIONS[key][:title]}): #{PartyComparison::SECTIONS[key][:chart]}" }.join("\n")}
    Os partidos de cada bloco (governista, centro, oposição) estão em blocs.
    Para a tabela "#{PartyComparison::SECTIONS['indicators'][:title]}", use party_ranking.
  DESC

  param :section, desc: "Seção da página: #{SECTIONS.join(', ')}"

  def execute(section:)
    return { erro: "Seção inválida. Use uma destas: #{SECTIONS.join(', ')}." } unless SECTIONS.include?(section)

    info = PartyComparison::SECTIONS[section]
    comparison.rows.each { |row| cite_party(row.party) }
    {
      secao: info[:title],
      o_que_mostra: [info[:chart], info[:reading]].compact.join(". "),
      como_e_calculado: info[:how],
      **send(section),
      acoes: next_steps(section)
    }.compact
  end

  private

  def comparison
    @comparison ||= PartyComparison.new
  end

  def blocs
    blocs = comparison.blocs
    no_data = blocs[PartyComparison::NO_DATA]
    {
      maioria_absoluta: PartyComparison::MAJORITY,
      total_de_cadeiras: comparison.total_seats,
      blocos: PartyComparison::BLOCS.map { |key, bloc| bloc_row(bloc, blocs[key]) },
      sem_dados: ({ cadeiras: no_data[:seats], partidos: no_data[:parties].map(&:label) } if no_data[:parties].any?)
    }
  end

  # Mesmas bolhas da página, incluindo as que ficam sobrepostas no desenho
  def positioning
    positioned = comparison.positioned
    return { aviso: "O mapa não é exibido: menos de 2 partidos têm governismo e coesão." } if positioned.size < 2

    {
      eixo_horizontal: "governismo (% de votações em que a maioria da bancada seguiu a orientação do Governo)",
      eixo_vertical: "coesão da bancada (100% = todos votam igual)",
      tamanho_da_bolha: "deputados da bancada",
      partidos: positioned.sort_by { |row| -row.seats }.map { |row| bubble_row(row) },
      bolhas_sobrepostas: helpers.positioning_chart(positioned)[:overlaps].map { |pair| overlap_text(pair) }.presence,
      fora_do_mapa: (comparison.rows - positioned).map(&:label).presence
    }
  end

  def bloc_row(bloc, data)
    { bloco: bloc[:label], criterio: bloc[:description], governismo_minimo_pct: bloc[:min], cadeiras: data[:seats],
      partidos: data[:parties].map do |row|
        { sigla: row.label, cadeiras: row.seats, governismo_pct: row.governism_pct }
      end }
  end

  def bubble_row(row)
    { sigla: row.label, nome: row.party.name, cadeiras: row.seats,
      bloco: PartyComparison::BLOCS.dig(row.bloc, :label), governismo_pct: row.governism_pct,
      votacoes_com_orientacao_do_governo: row.governism[:total], coesao_pct: row.cohesion }
  end

  # Mesmo texto da lista abaixo do mapa ("PCdoB dentro do PT")
  def overlap_text(overlap)
    "#{overlap[:small].label} #{overlap[:inside] ? 'dentro do' : 'sobre o'} #{overlap[:big].label}"
  end

  # Pares da matriz, do que mais vota junto ao que menos vota junto
  def affinity
    affinity = comparison.affinity
    pairs = affinity[:parties].combination(2).filter_map do |a, b|
      cell = affinity[:cells][[a.party.id, b.party.id]]
      { partidos: "#{a.label} e #{b.label}", mesmo_lado_pct: cell[:pct], votacoes_em_comum: cell[:common] } if cell
    end
    {
      ordem_na_matriz: affinity[:parties].map(&:label),
      pares: pairs.sort_by { |pair| [-pair[:mesmo_lado_pct], -pair[:votacoes_em_comum]] },
      fora_da_matriz: affinity[:left_out].map(&:label).presence
    }
  end

  def insights
    { destaques: comparison.insights.map { |_icon, title, text| { titulo: title, texto: text } } }
  end

  # A página da comparação (descartada quando o usuário já está nela) e um
  # aprofundamento que as outras ferramentas respondem
  def next_steps(section)
    largest = comparison.rows.first&.label
    deeper =
      case section
      when "blocs" then question("Partidos mais governistas", "Quais partidos são os mais governistas?")
      when "positioning" then question("Bancadas mais unidas", "Quais partidos têm a bancada mais coesa?")
      when "affinity"
        question("Com quem o #{largest} mais vota", "Com quais partidos o #{largest} mais vota?") if largest
      end
    [deeper, link("Ver comparação de partidos", routes.compare_parties_path)].compact
  end
end
