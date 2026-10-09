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

  def party_harpia_question(party, stats)
    partes = ["Com base nos dados da plataforma, explique de forma neutra o perfil do partido #{party.label} (#{party.name}) na Câmara dos Deputados."]
    partes << "Bancada atual: #{stats.deputies.size} deputados em #{stats.state_bench.size} estados."
    partes << "Coesão nas votações: #{stats.cohesion[:pct]}%." if stats.cohesion
    partes << "Federação na Câmara: #{stats.federation[:label]}." if stats.federation
    partes << "Candidatos a deputado federal em 2026: #{party.candidates.count}."
    partes.join(" ")
  end
end
