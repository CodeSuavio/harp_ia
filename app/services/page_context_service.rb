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

  # Texto curto para as instruções da IA, ou nil quando não reconhece a página
  def call
    return unless @path.start_with?("/") && !@path.start_with?("//")

    uri = URI.parse(@path)
    route = Rails.application.routes.recognize_path(uri.path)
    query = Rack::Utils.parse_nested_query(uri.query)

    describe(route, query)
  rescue URI::InvalidURIError, ActionController::RoutingError
    nil
  end

  private

  def describe(route, query)
    id = route[:id]

    case [route[:controller], route[:action]]
    when %w[deputies show]
      deputy = Deputy.includes(:party).find_by(id: id)
      deputy && "Perfil do deputado #{deputy.name} (#{deputy.party&.label}-#{deputy.state_label}, deputy_id #{deputy.id}), " \
                "aba \"#{tab_label(DeputiesController::TABS, DeputiesController::LEGACY_TABS.fetch(query['tab'], query['tab']))}\"" \
                "#{year_text(query)}"
    when %w[deputies compare]
      names = Deputy.where(id: Array(query["ids"])).map { |d| "#{d.name} (deputy_id #{d.id})" }
      "Comparação entre os deputados #{names.to_sentence}" if names.any?
    when %w[deputies index]
      "Lista de deputados#{filters_text(query)}"
    when %w[expenses index]
      deputy = Deputy.find_by(id: route[:deputy_id])
      deputy && "Gastos do deputado #{deputy.name} (deputy_id #{deputy.id})#{year_text(query)}"
    when %w[parties show]
      party = Party.find_by(id: id)
      party && "Página do partido #{party.label} (party_id #{party.id}), " \
               "aba \"#{tab_label(PartiesController::TABS, query['tab'])}\""
    when %w[parties compare]
      labels = Party.where(id: Array(query["ids"])).map { |p| "#{p.label} (party_id #{p.id})" }
      labels.any? ? "Comparação entre os partidos #{labels.to_sentence}" : "Comparação entre partidos"
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
