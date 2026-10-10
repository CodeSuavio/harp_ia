# Busca registros por nome ou termo, para a Harpia descobrir o id de um
# deputado, partido, projeto, votação ou candidato citado pelo usuário.
class SearchPlatformTool < ApplicationTool
  KINDS = %w[deputado partido projeto votacao candidato].freeze

  description <<~DESC
    Busca na base do Harp_IA deputados, partidos, projetos de lei, votações ou
    candidatos de 2026 pelo nome ou termo informado. Use antes das ferramentas
    de detalhes quando não souber o id do registro.
  DESC

  param :kind, desc: "Tipo de registro: #{KINDS.join(', ')}"
  param :query, desc: "Nome, sigla, número ou termo a buscar (ex.: 'Tabata', 'PT', 'PL 2630', 'reforma tributária')"

  def execute(kind:, query:)
    term = query.to_s.strip
    return { erro: "Informe um termo para buscar." } if term.blank?
    return { erro: "Tipo inválido. Use um destes: #{KINDS.join(', ')}." } unless KINDS.include?(kind)

    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    results = send("search_#{kind}", term, like)
    { resultados: results, total: results.size }
  end

  private

  def search_deputado(_term, like)
    Deputy.includes(:party).where("deputies.name ILIKE ?", like).order(:name).limit(LIST_LIMIT).map do |deputy|
      { id: deputy.id, nome: deputy.name, partido: party_label(deputy), uf: deputy.state_label, situacao: deputy.status }
    end
  end

  def search_partido(term, like)
    Party.where("label ILIKE :t OR name ILIKE :l OR former_labels ILIKE :l", t: term, l: like)
         .order(:label).limit(LIST_LIMIT).map do |party|
      { id: party.id, sigla: party.label, nome: party.name, ativo: party.active }
    end
  end

  def search_projeto(term, like)
    scope = Bill.all
    # "PL 2630/2020", "PL 2630" ou só o número
    if (match = term.match(/\A(?:(?<type>[a-z]+)\s*)?(?<number>\d+)(?:\s*\/\s*(?<year>\d{4}))?\z/i))
      scope = scope.where(number: match[:number].to_i)
      scope = scope.where("bill_type ILIKE ?", match[:type]) if match[:type]
      scope = scope.where(year: match[:year].to_i) if match[:year]
    else
      scope = scope.where("summary ILIKE :l OR keywords ILIKE :l OR bill_number ILIKE :l", l: like)
    end

    scope.order(Arel.sql("submission_date DESC NULLS LAST")).limit(LIST_LIMIT).map do |bill|
      { id: bill.id, numero: "#{bill.bill_type} #{bill.number}/#{bill.year}", ementa: bill.summary.to_s.truncate(200) }
    end
  end

  def search_votacao(_term, like)
    Poll.where("description ILIKE ?", like).order(date: :desc).limit(LIST_LIMIT).map do |poll|
      { id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(200), aprovada: poll.approval }
    end
  end

  def search_candidato(term, _like)
    Candidate.includes(:party).search(term).order(:ballot_name).limit(LIST_LIMIT).map do |candidate|
      { id: candidate.id, nome_de_urna: candidate.ballot_name, nome: candidate.name,
        partido: party_label(candidate), uf: candidate.state_label, numero: candidate.number }
    end
  end
end
