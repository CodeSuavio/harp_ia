# Próximos passos que a Harpia pode oferecer abaixo da resposta, como botões.
#
# As ferramentas (app/tools) registram aqui, a partir dos dados consultados,
# o que o usuário pode fazer em seguida:
# - question: uma pergunta que a própria Harpia responde com as ferramentas;
# - link: uma página da plataforma que já existe (caminho montado com as rotas).
#
# A IA vê só o id, o tipo e o rótulo de cada ação e escolhe as mais úteis pelo
# id. O destino fica no servidor, por isso ela não consegue inventar páginas.
# As ações "required" (continuar uma lista cortada) entram sempre.
class HarpiaActions
  MAX = 4

  Action = Struct.new(:id, :type, :label, :value, :required, keyword_init: true) do
    def to_h = { "type" => type, "label" => label, "value" => value }
  end

  def initialize
    @actions = {}
  end

  # Pergunta que a Harpia responde; o texto é enviado como a próxima pergunta
  def question(label, text, required: false)
    add("question", label, text, required)
  end

  # Página existente da plataforma
  def link(label, path, required: false)
    add("link", label, path, required)
  end

  # Ações escolhidas pela IA (ids), com as obrigatórias primeiro e as perguntas
  # de esclarecimento (texto livre, sem página) no fim. Descarta ids
  # desconhecidos, repetições e links para a página em que o usuário está.
  def pick(ids, current_path: nil, clarifications: [])
    chosen = @actions.values.select(&:required) + Array(ids).filter_map { |id| @actions[id.to_s] }
    chosen += clarifications.map { |text| Action.new(type: "question", label: text, value: text) }

    chosen.uniq(&:value)
          .reject { |action| action.type == "link" && same_page?(action.value, current_path) }
          .first(MAX)
          .map(&:to_h)
  end

  def find(id) = @actions[id]

  def all = @actions.values

  private

  # Devolve o que a IA vê da ação, no campo "acoes" do retorno da ferramenta
  def add(type, label, value, required)
    action = @actions.values.find { |existing| existing.value == value }
    unless action
      id = "a#{@actions.size + 1}"
      action = @actions[id] = Action.new(id: id, type: type, label: label, value: value, required: false)
    end
    action.required ||= required

    { id: action.id, tipo: type == "link" ? "página" : "pergunta", rotulo: action.label }
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
