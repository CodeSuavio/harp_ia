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
  # não tem ferramenta com os números). A chave é a página renderizada
  # ("controller#action", com "_selected" nas comparações de registros escolhidos).
  GUIDES = {
    "parties#compare" => {
      name: "comparação de partidos",
      sections: PartyComparison::SECTIONS,
      data: "use party_comparison com o id da seção; para a tabela de indicadores, party_ranking"
    },
    "deputies#compare" => { name: "panorama de deputados", sections: DeputyPanorama::SECTIONS, data: nil }
  }.freeze
  NO_DATA = "a Harpia ainda não tem os números destas seções: explique pelo texto de cada seção " \
            "e diga que os números estão na página".freeze

  attr_reader :key

  def self.find(key)
    new(key) if GUIDES.key?(key)
  end

  # Páginas cujos gráficos têm ferramenta com os números: a Harpia os conhece
  # em qualquer pergunta, pela descrição da ferramenta
  def self.with_data
    GUIDES.filter_map { |key, guide| new(key) if guide[:data] }
  end

  # { título => [nomes das páginas] } dos gráficos com o mesmo título em mais
  # de uma das páginas: citados sem a página, admitem mais de uma interpretação
  def self.shared_titles(guides)
    guides.uniq(&:key).flat_map { |guide| guide.titles.map { |title| [title, guide.name] } }
          .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
          .select { |_, names| names.size > 1 }
  end

  def initialize(key)
    @key = key
    @guide = GUIDES.fetch(key)
  end

  def name = @guide[:name]

  def titles = sections.values.pluck(:title)

  # Seções da página atual, com o que cada gráfico mostra
  def text
    lines = sections.map do |id, section|
      "- #{section[:title]} (id #{id}): #{[section[:chart], section[:reading]].compact.join('. ')}"
    end
    "SEÇÕES DA PÁGINA, de cima para baixo (#{@guide[:data] || NO_DATA}):\n#{lines.join("\n")}"
  end

  # Só o título e o tipo de cada gráfico, em uma linha, para reconhecer os
  # gráficos de uma página em que o usuário esteve antes
  def summary
    sections.values.map { |section| "#{section[:title]} (#{section[:chart]})" }.join("; ")
  end

  private

  def sections = @guide[:sections]
end
