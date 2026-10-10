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

    stats = PartyStats.new(party)
    expenses = stats.expenses
    adherence = stats.orientation_adherence
    affinity = stats.affinity

    {
      partido: { id: party.id, sigla: party.label, nome: party.name, numero: party.number,
                 ativo: party.active, lider: party.leader_name, pagina: routes.party_path(party) },
      bancada: { deputados: stats.deputies.size, no_inicio_da_legislatura: party.seats_at_start,
                 variacao: stats.bench_change, por_estado: stats.state_bench },
      gastos: expenses && expenses.except(:top).merge(
        total: money(expenses[:total]), monthly: money(expenses[:monthly]), chamber_monthly: money(expenses[:chamber_monthly]),
        maiores_gastos_mensais: expenses[:top].map { |deputy, value| { deputado: deputy.name, media_mensal: money(value) } }
      ),
      votacoes: {
        coesao_pct: stats.cohesion&.dig(:pct),
        coesao_media_dos_partidos_pct: DeputyMetrics.average_cohesion,
        adesao_a_orientacao: adherence && adherence.except(:against).merge(
          votacoes_contra_orientacao: adherence[:against].map { |poll, row| poll_row(poll, row) }
        ),
        votacoes_mais_divididas: stats.divided_polls.map { |poll, row| poll_row(poll, row) },
        afinidade: affinity&.transform_values { |rows| rows.map { |p, row| row.merge(partido: p.label) } },
        quem_mais_vota_contra_o_partido: stats.dissidents.map { |deputy, row| row.merge(deputado: deputy.name, id: deputy.id) }
      },
      projetos_de_lei: {
        total: stats.bills.count,
        por_tipo: stats.bill_types,
        temas: stats.bill_themes.map { |theme, count| [theme.name, count] }
      },
      candidatos_2026: stats.candidate_profile
    }
  end

  private

  def poll_row(poll, row)
    row.merge(id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(160))
  end
end
