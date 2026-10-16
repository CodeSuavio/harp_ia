# Projetos de lei por tema, partido, ano, tipo ou termo, com os mesmos filtros
# e a mesma ordem da listagem de projetos (BillSearch): os mais recentes primeiro.
#
# Responde perguntas como "quais projetos sobre saúde o PT apresentou?" sem a
# IA precisar buscar projeto por projeto.
class BillListTool < ApplicationTool
  MAX_LIMIT = 20

  description <<~DESC
    Lista projetos de lei, dos mais recentes para os mais antigos, com filtros
    por tema, partido, ano, tipo (PL, PEC, PLP...) e termo da ementa. São os
    mesmos projetos da página de projetos de lei. Use para perguntas como
    "quais projetos sobre saúde o PT apresentou?" ou "projetos sobre educação
    em 2025". Sem filtros, traz os projetos mais recentes. Para um único
    projeto, use bill_details.
  DESC

  param :theme, desc: "Nome do tema, ex.: Saúde, Educação (opcional)", required: false
  param :party, desc: "Sigla do partido do autor principal, ex.: PT (opcional)", required: false
  param :year, type: "integer", desc: "Ano de apresentação (opcional)", required: false
  param :type, desc: "Tipo do projeto: PL, PEC, PLP, PDL... (opcional)", required: false
  param :query, desc: "Termo para buscar na ementa e nas palavras-chave (opcional)", required: false
  param :limit, type: "integer", desc: "Quantidade de projetos (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(theme: nil, party: nil, year: nil, type: nil, query: nil, limit: nil) # rubocop:disable Metrics/ParameterLists
    error = lookup_error(theme, party)
    return error if error

    @filters = { theme: find_theme(theme), party: find_party(party), year: year.presence&.to_i,
                 type: type.presence&.upcase, query: query.to_s.strip.presence }.compact

    scope = BillSearch.new(query: @filters[:query], year: @filters[:year], theme: @filters[:theme]&.id,
                           party: @filters[:party]&.id, type: @filters[:type]).results
    result(scope, ranking_limit(limit, MAX_LIMIT))
  end

  private

  def result(scope, limit)
    total = scope.count
    bills = scope.includes(:party, :deputy, :themes).order(BillSearch::ORDER).limit(limit).to_a

    {
      filtros: filters_text.presence,
      ordem: "dos mais recentes para os mais antigos (data de apresentação)",
      total_de_projetos: total,
      projetos: bills.map { |bill| bill_row(bill) },
      recorte: recorte(bills.size, total),
      acoes: next_steps(bills, total)
    }.compact
  end

  def bill_row(bill)
    cite_deputy(bill.deputy)
    { id: bill.id, numero: number(bill), apresentado_em: bill.submission_date&.to_date,
      ementa: bill.summary.to_s.truncate(200), autor: bill.deputy&.name, partido: party_label(bill),
      temas: bill.themes.map(&:name) }.compact
  end

  # Continuação (página de projetos com os mesmos filtros) e o primeiro projeto da lista
  def next_steps(bills, total)
    return if bills.empty?

    [
      *continuation(shown: bills.size, total: total, max: MAX_LIMIT,
                    description: "#{"projetos de lei #{filters_text}".strip}, dos mais recentes para os mais antigos",
                    last: number(bills.last), page: page_path),
      question("Sobre o #{number(bills.first)}", "Do que trata o #{number(bills.first)}?")
    ]
  end

  def number(bill)
    "#{bill.bill_type} #{bill.number}/#{bill.year}"
  end

  # "sobre Saúde, do PT, de 2025, do tipo PEC, com o termo 'vacina'"
  def filters_text
    [("sobre #{@filters[:theme].name}" if @filters[:theme]), ("do #{@filters[:party].label}" if @filters[:party]),
     ("de #{@filters[:year]}" if @filters[:year]), ("do tipo #{@filters[:type]}" if @filters[:type]),
     ("com o termo '#{@filters[:query]}'" if @filters[:query])].compact.join(", ")
  end

  # Página de projetos com os mesmos filtros (mesmos parâmetros de BillsController)
  def page_path
    routes.bills_path({ q: @filters[:query], year: @filters[:year], theme: @filters[:theme]&.id,
                        party: @filters[:party]&.id, type: @filters[:type] }.compact)
  end
end
