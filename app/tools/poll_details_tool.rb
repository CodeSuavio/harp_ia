# Resultado de uma votação, por partido e por estado.
class PollDetailsTool < ApplicationTool
  description <<~DESC
    Retorna uma votação da Câmara: descrição, data, resultado, placar, voto
    de cada partido (maioria, coesão e orientação da liderança), orientação
    do Governo e deputados que votaram contra a maioria do próprio partido.
  DESC

  param :poll_id, type: "integer", desc: "Id da votação"

  def execute(poll_id:)
    poll = Poll.includes(:bills, :themes).find_by(id: poll_id)
    return not_found("Votação") unless poll

    breakdown = PollBreakdown.new(poll)

    {
      votacao: {
        id: poll.id,
        data: poll.date&.to_date,
        descricao: poll.description,
        orgao: poll.label_comission,
        aprovada: poll.approval,
        temas: poll.themes.map(&:name),
        projetos: poll.bills.map { |bill| { id: bill.id, numero: "#{bill.bill_type} #{bill.number}/#{bill.year}" } },
        pagina: routes.poll_path(poll)
      },
      placar: breakdown.tally,
      orientacao_do_governo: breakdown.government_orientation,
      por_partido: breakdown.by_party.map { |row| row.except(:party_id) },
      votos_contra_o_proprio_partido: breakdown.dissidents.first(20).map do |vote, majority|
        { deputado: vote.deputy.name, partido: vote.deputy.party.label, voto: vote.vote, maioria_do_partido: majority }
      end
    }
  end
end
