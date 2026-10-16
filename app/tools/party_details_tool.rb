# Indicadores de um partido, com os mesmos cálculos da página do partido.
class PartyDetailsTool < ApplicationTool
  description <<~DESC
    Retorna as análises de um partido: bancada por estado, gastos da bancada,
    coesão nas votações, adesão à orientação da liderança, afinidade com
    outros partidos, deputados que mais votam contra o partido, projetos de lei
    por tipo e tema e o perfil dos candidatos de 2026.
  DESC

  param :party_id, type: "integer", desc: "Id do partido"

  def execute(party_id:)
    party = Party.find_by(id: party_id)
    return not_found("Partido") unless party

    cite_party(party)

    stats = PartyStats.new(party)
    expenses = stats.expenses
    adherence = stats.orientation_adherence
    affinity = stats.affinity
    dissidents = stats.dissidents

    {
      partido: { id: party.id, sigla: party.label, nome: party.name, numero: party.number,
                 ativo: party.active, lider: party.leader_name },
      bancada: { deputados: stats.deputies.size, no_inicio_da_legislatura: party.seats_at_start,
                 variacao: stats.bench_change, por_estado: stats.state_bench },
      gastos: expenses && expenses.except(:top).merge(
        total: money(expenses[:total]), monthly: money(expenses[:monthly]), chamber_monthly: money(expenses[:chamber_monthly]),
        maiores_gastos_mensais: expenses[:top].map do |deputy, value|
          { deputado: deputy.name, media_mensal: money(value) }
        end
      ),
      votacoes: {
        coesao_pct: stats.cohesion&.dig(:pct),
        coesao_media_dos_partidos_pct: DeputyMetrics.average_cohesion,
        adesao_a_orientacao: adherence && adherence.except(:against).merge(
          votacoes_contra_orientacao: adherence[:against].map { |poll, row| poll_row(poll, row) }
        ),
        votacoes_mais_divididas: stats.divided_polls.map { |poll, row| poll_row(poll, row) },
        afinidade: affinity&.transform_values { |rows| rows.map { |p, row| row.merge(partido: p.label) } },
        quem_mais_vota_contra_o_partido: dissidents.map do |deputy, row|
          row.merge(deputado: deputy.name, id: deputy.id)
        end
      },
      projetos_de_lei: {
        total: stats.bills.count,
        por_tipo: stats.bill_types,
        temas: stats.bill_themes.map { |theme, count| [theme.name, count] }
      },
      candidatos_2026: stats.candidate_profile,
      acoes: next_steps(party, stats, dissidents)
    }
  end

  private

  # Páginas com as listas do partido e consultas sobre os seus deputados e candidatos
  def next_steps(party, stats, dissidents)
    label = party.label
    [
      link("Ver página do #{label}", routes.party_path(party)),
      (link("Ver deputados do #{label}", routes.deputies_path(party: party.id)) if stats.deputies.any?),
      (link("Ver candidatos do #{label}", routes.candidates_path(party: party.id)) if party.candidates.exists?),
      (link("Ver projetos do #{label}", routes.bills_path(party: party.id)) if stats.bills.exists?),
      link("Comparar com outros partidos", routes.compare_parties_path),
      (if stats.deputies.any?
         question("Quem do #{label} mais gasta", "Quais deputados do #{label} têm o maior gasto mensal?")
       end),
      (if dissidents.any?
         question("Quem mais vota contra o #{label}", "Quais deputados do #{label} mais votam contra o partido?")
       end),
      (if party.candidates.exists?
         question("Candidatos do #{label} por estado", "Quantos candidatos o #{label} tem em cada estado?")
       end)
    ].compact
  end

  def poll_row(poll, row)
    row.merge(id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(160))
  end
end
