# Gráficos de uma página da plataforma, para a Harpia reconhecer o gráfico
# citado pelo usuário ("o mapa de posicionamento", "o quadro azul").
#
# Identificar o gráfico é separado de consultar os números: o guia diz quais
# gráficos a página tem e o que cada um mostra; os números vêm das
# ferramentas indicadas em data (app/tools), quando existem.
# A página é reconhecida pelo PageContextService#guide.
class PageGuide
  # Páginas com gráficos: as seções, na ordem da página, e de onde vêm os
  # números de cada uma (data nil: a Harpia reconhece os gráficos, mas ainda
  # não tem ferramenta com os números; nas seções com data própria, cada uma
  # diz a consulta). A chave é a página renderizada ("controller#action",
  # com "_selected" nas comparações de registros escolhidos e "/aba" nas
  # páginas com abas).
  # record: o conteúdo depende de um registro (o deputado, o partido, os
  # escolhidos), então a página só vale como atual ou anterior, e não entre
  # os gráficos conhecidos em qualquer pergunta.
  BY_SECTION = "cada seção diz de onde vêm os números".freeze

  GUIDES = {
    "parties#compare" => {
      name: "comparação de partidos",
      sections: PartyComparison::SECTIONS,
      data: "use party_comparison com o id da seção; para a tabela de indicadores, party_ranking"
    },
    "deputies#compare" => {
      name: "panorama de deputados",
      sections: DeputyPanorama::SECTIONS,
      data: "use deputy_panorama com o id da seção; os filtros de estado e partido da página valem para indicators"
    },
    "parties#compare_selected" => {
      name: "comparação dos partidos escolhidos",
      sections: PartySelectionComparison::SECTIONS,
      data: "use selection_comparison com kind partidos e os party_id da página",
      record: true
    },
    "deputies#compare_selected" => {
      name: "comparação dos deputados escolhidos",
      sections: DeputyComparison::SECTIONS,
      data: "use selection_comparison com kind deputados e os deputy_id da página",
      record: true
    },
    **DeputiesController::TABS.to_h do |tab, label|
      ["deputies#show/#{tab}",
       { name: "perfil do deputado, aba #{label}", sections: PageSections::DEPUTY.fetch(tab), data: BY_SECTION,
         record: true }]
    end,
    **PartiesController::TABS.to_h do |tab, label|
      ["parties#show/#{tab}",
       { name: "página do partido, aba #{label}", sections: PageSections::PARTY.fetch(tab), data: BY_SECTION,
         record: true }]
    end,
    "pages#home" => { name: "mapa de partidos", sections: PageSections::PARTY_MAP, data: BY_SECTION },
    "deputies#index" => { name: "lista de deputados", sections: PageSections::DEPUTIES_LIST, data: BY_SECTION },
    "expense_alerts#index" => { name: "alertas de gastos", sections: PageSections::ALERTS, data: BY_SECTION },
    "polls#show" => { name: "página da votação", sections: PageSections::POLL, data: BY_SECTION, record: true },
    # Não é uma página: recursos que aparecem em todas (consultados pelo page_guide)
    "site" => { name: "todas as páginas", sections: PageSections::SITE, data: "não há números: explique pelo texto",
                site: true }
  }.freeze
  # Páginas que mostram o mesmo conteúdo de outra (a lista de partidos tem o
  # mesmo mapa da página inicial)
  SAME_AS = { "parties#index" => "pages#home" }.freeze
  NO_DATA = "a Harpia ainda não tem os números destas seções: explique pelo texto de cada seção " \
            "e diga que os números estão na página".freeze

  attr_reader :key

  def self.find(key)
    key = SAME_AS.fetch(key, key)
    new(key) if GUIDES.key?(key)
  end

  # Páginas cujos gráficos têm ferramenta com os números: a Harpia os conhece
  # em qualquer pergunta, pela descrição da ferramenta. As páginas de um
  # registro ficam de fora: sem o registro, não há o que reconhecer
  def self.with_data
    GUIDES.filter_map { |key, guide| new(key) if guide[:data] && !guide[:record] && !guide[:site] }
  end

  def self.all
    GUIDES.keys.map { |key| new(key) }
  end

  # [{ titles:, pages: }] das seções presentes em mais de uma das páginas,
  # agrupadas pelo id da seção ("A Câmara em blocos" e "A Câmara em blocos,
  # deputado a deputado" são o mesmo gráfico, em páginas diferentes): citadas
  # sem a página, admitem mais de uma interpretação
  def self.shared_sections(guides)
    guides.uniq(&:key).flat_map { |guide| guide.sections.map { |id, section| [id, section[:title], guide.name] } }
          .group_by(&:first).values.select { |rows| rows.size > 1 }
          .map { |rows| { titles: rows.map { |_, title, _| title }.uniq.sort, pages: rows.map(&:last).sort } }
  end

  # guide: o guia de GUIDES, ou outro no mesmo formato (testes)
  def initialize(key, guide = GUIDES.fetch(key))
    @key = key
    @guide = guide
  end

  def name = @guide[:name]

  def sections = @guide[:sections]

  # Seções da página atual, com o que cada gráfico mostra e, quando a seção
  # diz, de onde vêm os números
  def text
    lines = sections.map do |id, section|
      details = [section[:chart], section[:reading], ("números: #{section[:data]}" if section[:data])]
      "- #{section[:title]} (id #{id}): #{details.compact.join('. ')}"
    end
    "SEÇÕES DA PÁGINA, de cima para baixo (#{@guide[:data] || NO_DATA}):\n#{lines.join("\n")}"
  end

  # Só o título e o tipo de cada gráfico, em uma linha, para reconhecer os
  # gráficos de uma página em que o usuário esteve antes
  def summary
    sections.values.map { |section| "#{section[:title]} (#{section[:chart]})" }.join("; ")
  end
end
