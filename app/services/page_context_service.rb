# Descreve para a Harpia a página em que o usuário está, a partir do caminho
# enviado pelo widget (ex.: "/deputies/12?tab=expenses&year=2025").
#
# Assim a IA entende perguntas como "o que significa esse alerta?" sem que o
# usuário precise dizer de qual deputado, partido ou votação está falando.
# Os dados em si são buscados pela IA com as ferramentas de app/tools.
class PageContextService
  def initialize(path)
    @path = path.to_s
  end

  # Texto curto para as instruções da IA, ou nil quando não reconhece a página.
  # Fica salvo com a pergunta e volta no histórico da conversa.
  def call
    route, query = recognize
    describe(route, query) if route
  end

  # Gráficos da página (PageGuide), ou nil quando ela não tem gráficos mapeados.
  # Não é salvo com a pergunta, para não repetir o guia a cada mensagem do histórico.
  def guide
    route, query = recognize
    PageGuide.find(page_key(route, query)) if route
  end

  private

  def recognize
    return unless @path.start_with?("/") && !@path.start_with?("//")

    uri = URI.parse(@path)
    [Rails.application.routes.recognize_path(uri.path), Rack::Utils.parse_nested_query(uri.query)]
  rescue URI::InvalidURIError, ActionController::RoutingError
    nil
  end

  # A comparação com registros escolhidos (?ids[]=) é outra página
  def page_key(route, query)
    key = "#{route[:controller]}##{route[:action]}"
    route[:action] == "compare" && query.key?("ids") ? "#{key}_selected" : key
  end

  def describe(route, query)
    id = route[:id]

    case [route[:controller], route[:action]]
    when %w[deputies show]
      deputy = Deputy.includes(:party).find_by(id: id)
      deputy && "Perfil do deputado #{deputy.name} (#{deputy.party&.label}-#{deputy.state_label}, deputy_id #{deputy.id}), " \
                "aba \"#{tab_label(DeputiesController::TABS,
                                   DeputiesController::LEGACY_TABS.fetch(query['tab'], query['tab']))}\"" \
                "#{year_text(query)}"
    when %w[deputies compare]
      if query.key?("ids")
        names = Deputy.where(id: Array(query["ids"])).map { |d| "#{d.name} (deputy_id #{d.id})" }
        "Comparação entre os deputados #{names.to_sentence}" if names.any?
      else
        # Sem deputados escolhidos, é o panorama de todos os deputados
        "Panorama de comparação entre os deputados#{filters_text(query)}#{sort_text(DeputyPanorama::SORTS, query)}"
      end
    when %w[deputies index]
      "Lista de deputados#{filters_text(query)}#{sort_text(DeputiesController::SORTS, query)}"
    when %w[expenses index]
      deputy = Deputy.find_by(id: route[:deputy_id])
      deputy && "Gastos do deputado #{deputy.name} (deputy_id #{deputy.id})#{year_text(query)}"
    when %w[parties show]
      party = Party.find_by(id: id)
      party && "Página do partido #{party.label} (party_id #{party.id}), " \
               "aba \"#{tab_label(PartiesController::TABS, query['tab'])}\""
    when %w[parties compare]
      labels = Party.where(id: Array(query["ids"])).map { |p| "#{p.label} (party_id #{p.id})" }
      if labels.any?
        "Comparação entre os partidos #{labels.to_sentence}"
      else
        "Comparação entre partidos#{sort_text(PartyComparison::SORTS, query)}"
      end
    when %w[parties index]
      "Lista de partidos#{filters_text(query)}"
    when %w[bills show]
      bill = Bill.find_by(id: id)
      bill && "Projeto de lei #{bill.bill_type} #{bill.number}/#{bill.year} (bill_id #{bill.id})"
    when %w[bills index]
      "Lista de projetos de lei#{filters_text(query)}"
    when %w[polls show]
      poll = Poll.find_by(id: id)
      poll && "Votação de #{poll.date&.strftime('%d/%m/%Y')}: \"#{poll.description.to_s.truncate(120)}\" (poll_id #{poll.id})"
    when %w[polls index]
      "Lista de votações#{filters_text(query)}"
    when %w[candidates show]
      candidate = Candidate.includes(:party).find_by(id: id)
      candidate && "Candidato #{candidate.ballot_name} (#{candidate.party&.label}-#{candidate.state_label}, candidate_id #{candidate.id})"
    when %w[candidates index]
      "Lista de candidatos de 2026#{filters_text(query)}"
    when %w[pages home]
      "Página inicial do Harp_IA"
    end
  end

  # Ordenação escolhida pelo usuário, para entender "quem lidera esse ranking?"
  def sort_text(sorts, query)
    sort = sorts[query["sort"]]
    return "" unless sort

    direction = query["dir"] == "asc" && sort[:default] != :asc ? ", do menor para o maior" : ""
    ", ordenada por \"#{sort[:label].delete_prefix('Ordenar por ')}\"#{direction}"
  end

  def tab_label(tabs, tab)
    tabs.fetch(tab.to_s, tabs.values.first)
  end

  def year_text(query)
    query["year"].present? ? ", ano #{query['year'].to_i}" : ""
  end

  # Filtros aplicados na listagem (busca, estado, partido...), para contexto
  def filters_text(query)
    filters = query.except("page", "sort", "dir").select { |_, value| value.is_a?(String) && value.present? }
    filters.any? ? " com os filtros #{filters.map { |k, v| "#{k}=#{v.truncate(40)}" }.join(', ')}" : ""
  end
end
