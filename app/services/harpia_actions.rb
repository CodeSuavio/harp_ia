# Próximos passos que a Harpia pode oferecer abaixo da resposta, como botões.
#
# As ferramentas (app/tools) registram aqui, a partir dos dados consultados,
# o que o usuário pode fazer em seguida:
# - question: uma pergunta que a própria Harpia responde com as ferramentas;
# - link: uma página da plataforma que já existe (caminho montado com as rotas).
#
# A IA vê só o id, o tipo e o rótulo de cada ação e escolhe as mais úteis pelo
# id. O destino fica no servidor, por isso ela não consegue inventar páginas.
#
# A continuação de uma lista cortada ("Ver mais", "Ver lista completa") entra
# sozinha, mas só quando a resposta mostrou a lista (o último item aparece no
# texto) e o usuário não está na página que já mostra a lista inteira.
class HarpiaActions
  MAX = 4

  # shown_if: padrões do último item da lista, um dos quais precisa aparecer na
  # resposta; list_page: a página com a lista inteira
  Action = Struct.new(:id, :type, :label, :value, :shown_if, :list_page, keyword_init: true) do
    def to_h = { "type" => type, "label" => label, "value" => value }

    def continuation? = shown_if.present?
  end

  def initialize
    @actions = {}
  end

  # Pergunta que a Harpia responde; o texto é enviado como a próxima pergunta
  def question(label, text, shown_if: nil)
    add("question", label, text, shown_if: shown_if)
  end

  # Página existente da plataforma
  def link(label, path, shown_if: nil, list_page: nil)
    add("link", label, path, shown_if: shown_if, list_page: list_page)
  end

  # Botões da resposta: a continuação de uma lista mostrada, as perguntas de
  # descoberta escritas pela IA e as ações que ela escolheu (ids). As
  # descobertas substituem as perguntas prontas das ferramentas, que costumam
  # repetir a mesma ideia com outras palavras; as páginas continuam. Com
  # perguntas de esclarecimento, só elas e as ações escolhidas. Descarta ids
  # desconhecidos, repetições e links para a página em que o usuário está.
  def pick(ids, content: nil, current_path: nil, discoveries: [], clarifications: [])
    chosen = Array(ids).filter_map { |id| @actions[id.to_s] }.reject(&:continuation?)

    buttons(chosen, content, current_path, discoveries, clarifications)
      .uniq(&:value)
      .reject { |action| action.type == "link" && same_page?(action.value, current_path) }
      .first(MAX)
      .map(&:to_h)
  end

  def find(id) = @actions[id]

  def all = @actions.values

  private

  # Devolve o que a IA vê da ação, no campo "acoes" do retorno da ferramenta
  def add(type, label, value, shown_if: nil, list_page: nil)
    action = @actions.values.find { |existing| existing.value == value }
    unless action
      id = "a#{@actions.size + 1}"
      action = @actions[id] = Action.new(id: id, type: type, label: label, value: value,
                                         shown_if: shown_if, list_page: list_page)
    end

    { id: action.id, tipo: type == "link" ? "página" : "pergunta", rotulo: action.label }
  end

  def buttons(chosen, content, current_path, discoveries, clarifications)
    return chosen + questions(clarifications) if clarifications.any?

    chosen = chosen.select { |action| action.type == "link" } if discoveries.any?
    continuations(content, current_path) + questions(discoveries) + chosen
  end

  def questions(texts)
    texts.map { |text| Action.new(type: "question", label: text, value: text) }
  end

  # Continuações das listas que a resposta mostrou, fora da página da lista
  def continuations(content, current_path)
    @actions.values.select do |action|
      action.continuation? && action.shown_if.any? { |pattern| content.to_s.match?(pattern) } &&
        !(action.list_page && same_listing?(action.list_page, current_path))
    end
  end

  # O usuário já está na página da lista, com qualquer ordenação ou filtro
  # (ex.: a tabela de indicadores da comparação de partidos)
  def same_listing?(page, current_path)
    key = PageContextService.new(page).key
    key.present? && key == PageContextService.new(current_path).key
  end

  # O link não leva a nada novo quando abre a mesma página com os mesmos
  # filtros (ex.: "Ver perfil" estando no perfil, em qualquer aba)
  def same_page?(path, current_path)
    return false if current_path.blank?

    link = URI.parse(path)
    current = URI.parse(current_path)
    link_query = Rack::Utils.parse_query(link.query)
    current_query = Rack::Utils.parse_query(current.query)

    link.path == current.path && link_query.all? { |key, value| current_query[key] == value }
  rescue URI::InvalidURIError
    false
  end
end
