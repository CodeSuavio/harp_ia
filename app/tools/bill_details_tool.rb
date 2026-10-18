# Dados de um projeto de lei e das votações ligadas a ele.
class BillDetailsTool < ApplicationTool
  description "Retorna um projeto de lei: ementa, autores, partido, temas, palavras-chave e votações relacionadas."

  param :bill_id, type: "integer", desc: "Id do projeto de lei"

  def execute(bill_id:)
    bill = Bill.includes(:party, :themes, :authors).find_by(id: bill_id)
    return not_found("Projeto de lei") unless bill

    polls = bill.votings.order(date: :desc).limit(LIST_LIMIT).to_a
    bill.authors.each { |deputy| cite_deputy(deputy) }

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
        link_oficial: bill.url
      },
      votacoes: polls.map do |poll|
        { id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(200),
          aprovada: poll.approval }
      end,
      acoes: next_steps(bill, polls)
    }
  end

  private

  # Página do projeto, das suas votações, do autor e de outros projetos do tema
  def next_steps(bill, polls)
    author = bill.authors.first
    theme = bill.themes.first
    [
      link("Ver #{bill.bill_type} #{bill.number}/#{bill.year}", routes.bill_path(bill)),
      *polls.first(2).map { |poll| link("Ver votação de #{poll.date&.strftime('%d/%m/%Y')}", routes.poll_path(poll)) },
      (question("Sobre #{author.name}", "Mostre os dados do deputado #{author.name}") if author),
      (link("Ver projetos sobre #{theme.name}", routes.bills_path(theme: theme.id)) if theme)
    ].compact
  end
end
