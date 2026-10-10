# Dados de um candidato das eleições de 2026.
class CandidateDetailsTool < ApplicationTool
  description "Retorna um candidato das eleições de 2026: partido, estado, número, perfil e se já é deputado em exercício."

  param :candidate_id, type: "integer", desc: "Id do candidato"

  def execute(candidate_id:)
    candidate = Candidate.includes(:party, :current_deputy).find_by(id: candidate_id)
    return not_found("Candidato") unless candidate

    deputy = candidate.current_deputy

    {
      candidato: {
        id: candidate.id,
        nome: candidate.name,
        nome_de_urna: candidate.ballot_name,
        numero: candidate.number,
        partido: party_label(candidate),
        uf: candidate.state_label,
        situacao_da_candidatura: candidate.candidacy_status,
        ocupacao: candidate.occupation,
        escolaridade: candidate.education_level,
        genero: candidate.gender,
        cor_raca: candidate.race_color,
        concorre_a_reeleicao: candidate.reelection?,
        pagina: routes.candidate_path(candidate)
      },
      deputado_em_exercicio: deputy && { id: deputy.id, nome: deputy.name, observacao: "Use deputy_details para ver a atuação." }
    }
  end
end
