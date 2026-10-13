# Busca e filtros da listagem de projetos de lei (/bills). Usada pela página
# (BillsController) e pela Harpia (BillListTool), para as duas mostrarem os
# mesmos projetos, na mesma ordem.
class BillSearch
  NUMBER_QUERY = %r{\A\s*(PL|PLP|PEC|PDL|PRC|MPV)\s*(?:n[ºo°.]?\s*)?([\d.]+)(?:\s*/\s*(\d{4}))?\s*\z}i
  # Mais recentes primeiro
  ORDER = { submission_date: :desc, id: :desc }.freeze

  # filters: year, theme (id), party (id), type (PL, PEC...) e author (id do deputado)
  def initialize(scope = Bill.all, query: nil, **filters)
    @scope = scope
    @query = query
    @filters = filters.compact_blank
  end

  # Projetos do recorte; except: um filtro a ignorar (ex.: :theme, para contar os temas)
  def results(except: nil)
    @filters.except(except).reduce(search(@scope)) { |scope, (key, value)| apply(scope, key, value) }
  end

  private

  def search(scope)
    return scope if @query.blank?

    if (match = @query.match(NUMBER_QUERY))
      found = scope.where(bill_type: match[1].upcase, number: match[2].delete(".").to_i)
      return match[3] ? found.where(year: match[3].to_i) : found
    end

    scope.where("bills.summary ILIKE :q OR bills.keywords ILIKE :q", q: "%#{Bill.sanitize_sql_like(@query.strip)}%")
  end

  def apply(scope, key, value)
    case key
    when :year then scope.where(year: value.to_i)
    when :theme then scope.where(id: BillTheme.where(theme_id: value).select(:bill_id))
    when :party then scope.where(party_id: value)
    when :type then scope.where(bill_type: value)
    when :author then scope.where(id: BillAuthor.where(deputy_id: value).select(:bill_id))
    else scope
    end
  end
end
