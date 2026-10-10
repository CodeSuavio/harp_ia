# Dados de um projeto de lei e das votações ligadas a ele.
class BillDetailsTool < ApplicationTool
  description "Retorna um projeto de lei: ementa, autores, partido, temas, palavras-chave e votações relacionadas."

  param :bill_id, type: "integer", desc: "Id do projeto de lei"

  def execute(bill_id:)
    bill = Bill.includes(:party, :themes, :authors).find_by(id: bill_id)
    return not_found("Projeto de lei") unless bill

    {
      projeto: {
        id: bill.id,
        numero: "#{bill.bill_type} #{bill.number}/#{bill.year}",
        apresentado_em: bill.submission_date&.to_date,
        ementa: bill.summary,
        palavras_chave: bill.keywords,
        partido: party_label(bill),
        autores: bill.authors.map { |deputy| { id: deputy.id, nome: deputy.name } },
        temas: bill.themes.map(&:name),
        link_oficial: bill.url,
        pagina: routes.bill_path(bill)
      },
      votacoes: bill.votings.order(date: :desc).limit(LIST_LIMIT).map do |poll|
        { id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(200), aprovada: poll.approval }
      end
    }
  end
end
