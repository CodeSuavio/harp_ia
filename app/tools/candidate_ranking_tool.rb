# Contagem dos candidatos a deputado federal em 2026 agrupada por um atributo
# (estado, partido, gênero etc.), com os mesmos números dos filtros da página
# de candidatos (CandidatesController#index).
#
# Responde perguntas sobre o conjunto dos candidatos ("qual estado tem mais
# candidatos?", "quantas mulheres concorrem pelo PT?") sem a IA precisar
# consultar candidato por candidato.
class CandidateRankingTool < ApplicationTool
  MAX_LIMIT = 30

  GROUPS = {
    "state" => { label: "Estado (UF)", column: "candidates.state_label" },
    "party" => { label: "Partido", column: "parties.label" },
    "gender" => { label: "Gênero", column: "candidates.gender" },
    "race_color" => { label: "Cor/raça", column: "candidates.race_color" },
    "education_level" => { label: "Escolaridade", column: "candidates.education_level" },
    "occupation" => { label: "Ocupação", column: "candidates.occupation" }
  }.freeze

  description <<~DESC
    Conta os candidatos a deputado federal em 2026 agrupados por:
    #{GROUPS.map { |key, row| "#{key} (#{row[:label]})" }.join(', ')}.
    Pode filtrar por estado (UF), partido (sigla) e gênero. Use para perguntas
    sobre o conjunto dos candidatos, como "qual estado tem mais candidatos?",
    "quais partidos lançaram mais candidatos?", "quantas mulheres concorrem em
    SP?" ou "quantos candidatos o PT tem na Bahia?".
  DESC

  param :group_by, desc: "Atributo usado para agrupar: #{GROUPS.keys.join(', ')}"
  param :order, desc: "desc (do maior para o menor, padrão) ou asc (do menor para o maior)", required: false
  param :state, desc: "UF para filtrar, ex.: SP (opcional)", required: false
  param :party, desc: "Sigla do partido para filtrar, ex.: PT (opcional)", required: false
  param :gender, desc: "Gênero para filtrar: FEMININO ou MASCULINO (opcional)", required: false
  param :limit, type: "integer", desc: "Quantidade de grupos (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(group_by:, order: nil, state: nil, party: nil, gender: nil, limit: nil) # rubocop:disable Metrics/ParameterLists
    return { erro: "Agrupamento inválido. Use um destes: #{GROUPS.keys.join(', ')}." } unless GROUPS.key?(group_by)

    party_record = Party.find_by("label ILIKE ?", party.to_s.strip) if party.present?
    return not_found("Partido") if party.present? && !party_record

    filters = filters_for(state, party_record, gender)
    candidates = Candidate.where(filters)
    direction = order.to_s == "asc" ? :asc : :desc
    counts, missing = counts_for(candidates, group_by).partition { |value, _| value.present? }
    total = candidates.count
    rows = ranking(counts, total, direction, ranking_limit(limit, MAX_LIMIT))

    {
      agrupado_por: GROUPS[group_by][:label],
      como_e_calculado: "número de candidaturas a deputado federal em 2026 registradas no TSE, " \
                        "contadas por #{GROUPS[group_by][:label].downcase}.",
      unidade: "candidatos",
      ordem: order_label(direction),
      filtros: { uf: filters[:state_label], partido: party_record&.label, genero: filters[:gender] }.compact.presence,
      total_de_candidatos: total,
      total_de_grupos: counts.size,
      ranking: rows,
      recorte: recorte(rows.size, counts.size),
      candidatos_sem_informacao: missing.sum { |_, count| count }.nonzero?,
      # Não há página com a contagem por grupo; a página de candidatos mostra
      # as candidaturas de cada grupo (ou as contadas, com os filtros)
      acoes: [
        *continuation(shown: rows.size, total: counts.size, max: MAX_LIMIT,
                      description: ranking_description(group_by, direction, filters, party_record)),
        *group_links(group_by, rows, filters),
        (link("Ver os candidatos#{filters_text(filters, party_record)}", candidates_page(filters)) if filters.any?)
      ].compact.presence
    }.compact
  end

  private

  # Mesmos parâmetros dos filtros da página de candidatos
  def filters_for(state, party, gender)
    { state_label: state.presence&.upcase, party_id: party&.id, gender: gender.presence&.upcase }.compact
  end

  # [[valor, quantidade], ...]
  def counts_for(candidates, group_by)
    candidates.left_joins(:party).group(Arel.sql(GROUPS[group_by][:column])).count.to_a
  end

  def ranking(counts, total, direction, limit)
    sorted = counts.sort_by { |value, count| [direction == :desc ? -count : count, value] }
    sorted.first(limit).each_with_index.map do |(value, count), index|
      { posicao: index + 1, grupo: value, candidatos: count, percentual: (count * 100.0 / total).round(1) }
    end
  end

  # "candidatos de 2026 por partido, do maior para o menor, em SP, gênero feminino"
  def ranking_description(group_by, direction, filters, party)
    ["candidatos de 2026 por #{GROUPS[group_by][:label].downcase}", order_label(direction),
     filters_text(filters, party).delete_prefix(" (").delete_suffix(")").presence].compact.join(", ")
  end

  # " (em SP, do PT, gênero feminino)"
  def filters_text(filters, party)
    parts = [("em #{filters[:state_label]}" if filters[:state_label]), ("do #{party.label}" if party),
             ("gênero #{filters[:gender].downcase}" if filters[:gender])].compact
    parts.any? ? " (#{parts.join(', ')})" : ""
  end

  # Agrupamentos que também são filtros da página de candidatos: cada grupo
  # exibido leva às suas candidaturas (ex.: as mulheres candidatas em SP)
  def group_links(group_by, rows, filters)
    key = { "state" => :state_label, "party" => :party_id, "gender" => :gender }[group_by]
    return [] unless key

    parties = Party.where(label: rows.pluck(:grupo)).index_by(&:label) if group_by == "party"
    rows.filter_map do |row|
      value = parties ? parties[row[:grupo]]&.id : row[:grupo]
      next unless value

      group_filters = filters.merge(key => value)
      party = Party.find_by(id: group_filters[:party_id]) if group_filters[:party_id]
      link("Ver os candidatos#{filters_text(group_filters, party)}", candidates_page(group_filters))
    end
  end

  # Mesmos parâmetros dos filtros da página de candidatos
  def candidates_page(filters)
    routes.candidates_path({ state: filters[:state_label], party: filters[:party_id],
                             gender: filters[:gender] }.compact)
  end
end
