# Busca e filtros da listagem de votações (/polls). Usada pela página
# (PollsController) e pela Harpia (PollListTool), para as duas mostrarem as
# mesmas votações, na mesma ordem.
class PollSearch
  # Mais recentes primeiro
  ORDER = { date: :desc, id: :desc }.freeze

  # filters: year, theme (id), approval ("1" aprovada, "0" rejeitada) e
  # government ("venceu" ou "perdeu", conforme a orientação do Governo).
  # all: inclui as votações sem votos nominais registrados
  def initialize(scope = Poll.all, query: nil, all: false, **filters)
    @scope = scope
    @query = query
    @all = all
    @filters = filters.compact_blank
  end

  # Votações do recorte; except: um filtro a ignorar (ex.: :theme, para contar os temas)
  def results(except: nil)
    @filters.except(except).reduce(base) { |scope, (key, value)| apply(scope, key, value) }
  end

  private

  def base
    scope = @scope
    scope = scope.where("polls.description ILIKE ?", "%#{Poll.sanitize_sql_like(@query.strip)}%") if @query.present?
    @all ? scope : scope.where(id: Vote.select(:poll_id))
  end

  def apply(scope, key, value)
    case key
    when :year then scope.where("EXTRACT(YEAR FROM polls.date) = ?", value.to_i)
    when :theme then scope.where(id: PollTheme.where(theme_id: value).select(:poll_id))
    when :approval then scope.where(approval: value == "1")
    when :government then scope.where(id: government_polls(value))
    else scope
    end
  end

  # Votações em que o resultado oficial coincidiu (venceu) ou não (perdeu) com a orientação do Governo
  def government_polls(value)
    comparison = value == "perdeu" ? "<>" : "="
    PollOrientation.joins(:poll)
                   .where(label: "Governo", orientation: %w[Sim Não])
                   .where.not(polls: { approval: nil })
                   .where("polls.description NOT LIKE 'Mantido o texto%'")
                   .where("(poll_orientations.orientation = 'Sim') #{comparison} polls.approval")
                   .select(:poll_id)
  end
end
