# Importa propostas a partir de uma lista (JSON) no formato:
#
#   [{
#     "source_kind": "programa_partido" | "plano_executivo" | "campanha",
#     "author": "Candidato X ao governo de SP",       # opcional
#     "party": "PT",                                    # sigla; obrigatório sem "deputy_json_id"
#     "deputy_json_id": 204554,                         # id da Câmara; só para "campanha"
#     "state": "SP",                                    # opcional: restringe à bancada do estado
#     "theme": "health",                                # slug do tema (ver ThemeClassifier::CATALOG)
#     "title": "Ampliar o SUS",
#     "excerpt": "Trecho literal da proposta...",
#     "source_url": "https://...",
#     "polls": [{ "json_id": "2412345-67", "favorable_vote": "Sim" }]  # opcional
#   }]
#
# Propostas com o mesmo título, tema e autoria são atualizadas em vez de duplicadas.
class ProposalImporter
  def initialize(rows)
    @rows = Array(rows)
  end

  def call
    created = 0
    errors = []

    @rows.each_with_index do |row, index|
      proposal = build(row)
      if proposal.save
        link_polls(proposal, row["polls"], errors, index)
        created += 1
      else
        errors << "linha #{index + 1}: #{proposal.errors.full_messages.to_sentence}"
      end
    end

    { created: created, errors: errors }
  end

  private

  def build(row)
    party = Party.find_by(label: row["party"]) if row["party"].present?
    deputy = Deputy.find_by(json_id: row["deputy_json_id"]) if row["deputy_json_id"].present?
    theme = Theme.find_by(slug: row["theme"])

    proposal = Proposal.find_or_initialize_by(
      title: row["title"], theme: theme, party: party || deputy&.party, deputy: deputy
    )
    proposal.assign_attributes(
      source_kind: row["source_kind"],
      author: row["author"],
      state_label: row["state"].presence,
      excerpt: row["excerpt"],
      source_url: row["source_url"]
    )
    proposal
  end

  def link_polls(proposal, polls, errors, index)
    Array(polls).each do |item|
      poll = Poll.find_by(json_id: item["json_id"].to_s)
      next errors << "linha #{index + 1}: votação #{item['json_id']} não encontrada" unless poll

      link = proposal.proposal_polls.find_or_initialize_by(poll: poll)
      link.favorable_vote = item["favorable_vote"]
      errors << "linha #{index + 1}: #{link.errors.full_messages.to_sentence}" unless link.save
    end
  end
end
