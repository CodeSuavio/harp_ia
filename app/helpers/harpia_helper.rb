module HarpiaHelper
  def harpia_question(candidate, overview = nil)
    nome = candidate.ballot_name.presence || candidate.name
    partes = ["Com base nos dados da plataforma, explique de forma neutra quem é #{nome} (#{candidate.party.label}-#{candidate.state_label}), candidato número #{candidate.number}."]

    if overview
      partes << "Gastos parlamentares totais: #{brl(overview.total_spent.to_f)} em #{overview.expense_count} despesas."
      partes << "Votações registradas: #{overview.votes_count}. Proposições de autoria: #{overview.bills_count}."
    end

    partes.join(" ")
  end
end
