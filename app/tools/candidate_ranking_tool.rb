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
  param :limit, type: "integer", desc: "Quantidade de grupos (padrão #{LIST_LIMIT}, máximo #{MAX_LIMIT})",
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

    {
      agrupado_por: GROUPS[group_by][:label],
      como_e_calculado: "número de candidaturas a deputado federal em 2026 registradas no TSE, " \
                        "contadas por #{GROUPS[group_by][:label].downcase}.",
      unidade: "candidatos",
      ordem: direction == :desc ? "do maior para o menor" : "do menor para o maior",
      filtros: { uf: filters[:state_label], partido: party_record&.label, genero: filters[:gender] }.compact.presence,
      total_de_candidatos: total,
      total_de_grupos: counts.size,
      ranking: ranking(counts, total, direction, limit),
      candidatos_sem_informacao: missing.sum { |_, count| count }.nonzero?,
      pagina: routes.candidates_path(state: filters[:state_label], party: filters[:party_id], gender: filters[:gender])
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
    sorted.first(limit_for(limit)).each_with_index.map do |(value, count), index|
      { posicao: index + 1, grupo: value, candidatos: count, percentual: (count * 100.0 / total).round(1) }
    end
  end

  def limit_for(limit)
    limit.to_i.positive? ? [limit.to_i, MAX_LIMIT].min : LIST_LIMIT
  end
end
