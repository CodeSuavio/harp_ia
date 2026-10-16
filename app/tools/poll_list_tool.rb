# Votações por tema, ano, resultado, resultado para o Governo ou termo, com os
# mesmos filtros e a mesma ordem da listagem de votações (PollSearch): as mais
# recentes primeiro.
#
# O partido não filtra as votações: acrescenta a cada uma os votos da bancada
# e a orientação da liderança (a mesma da aba Votações do partido, PartyStats).
# Assim a lista é sempre a mesma da página de votações com os mesmos filtros.
class PollListTool < ApplicationTool
  MAX_LIMIT = 20
  RESULTS = { "approved" => "1", "rejected" => "0" }.freeze
  RESULT_LABELS = { "approved" => "aprovadas", "rejected" => "rejeitadas" }.freeze
  # Mesmos valores do filtro "governo" da página de votações
  GOVERNMENT = { "won" => "venceu", "lost" => "perdeu" }.freeze

  description <<~DESC
    Lista votações nominais da Câmara, das mais recentes para as mais antigas,
    com filtros por tema, ano, resultado (aprovada ou rejeitada), resultado
    para o Governo (venceu ou perdeu) e termo da descrição. São as mesmas
    votações da página de votações. Com partido, acrescenta a cada votação
    como a bancada votou e a orientação da liderança, sem mudar quais
    votações entram. Use para perguntas como "quais foram as votações sobre
    meio ambiente?", "em quais votações o governo perdeu?" ou "como o PT
    votou nas votações sobre segurança pública?". Sem filtros, traz as
    votações mais recentes. Para uma única votação, use poll_details.
  DESC

  param :theme, desc: "Nome do tema, ex.: Saúde, Meio ambiente (opcional)", required: false
  param :party, desc: "Sigla do partido, ex.: PT, para ver como a bancada votou (opcional)", required: false
  param :year, type: "integer", desc: "Ano da votação (opcional)", required: false
  param :result, desc: "approved (aprovadas) ou rejected (rejeitadas) (opcional)", required: false
  param :government, desc: "won (o Governo venceu) ou lost (o Governo perdeu): o resultado oficial coincidiu " \
                           "ou não com a orientação Sim/Não do Governo (opcional)", required: false
  param :query, desc: "Termo para buscar na descrição da votação (opcional)", required: false
  param :limit, type: "integer", desc: "Quantidade de votações (padrão #{RANKING_LIMIT}, máximo #{MAX_LIMIT})",
                required: false

  def execute(theme: nil, party: nil, year: nil, result: nil, government: nil, query: nil, limit: nil) # rubocop:disable Metrics/ParameterLists
    error = lookup_error(theme, party)
    return error if error

    @filters = { theme: find_theme(theme), party: find_party(party), year: year.presence&.to_i,
                 result: (result if RESULTS.key?(result)), government: GOVERNMENT[government],
                 query: query.to_s.strip.presence }.compact
    cite_party(@filters[:party])
    list(ranking_limit(limit, MAX_LIMIT))
  end

  private

  def list(limit)
    scope = PollSearch.new(query: @filters[:query], year: @filters[:year], theme: @filters[:theme]&.id,
                           approval: RESULTS[@filters[:result]], government: @filters[:government]).results

    total = scope.count
    polls = scope.includes(:themes, :bills).order(PollSearch::ORDER).limit(limit).to_a

    {
      filtros: filters_text.presence,
      ordem: "das mais recentes para as mais antigas",
      total_de_votacoes: total,
      votacoes: rows(polls),
      recorte: recorte(polls.size, total),
      observacao: notes,
      acoes: next_steps(polls, total)
    }.compact
  end

  def rows(polls)
    ids = polls.map(&:id)
    tallies = Vote.where(poll_id: ids).group(:poll_id, :vote).count
    party_tallies = party_votes.where(poll_id: ids).group(:poll_id, :vote).count if @filters[:party]
    orientations = PartyStats.new(@filters[:party], []).orientations if @filters[:party]
    government = PollOrientation.where(label: "Governo", poll_id: ids).pluck(:poll_id, :orientation).to_h

    polls.map do |poll|
      {
        id: poll.id, data: poll.date&.to_date, descricao: poll.description.to_s.truncate(200),
        aprovada: poll.approval, placar: tally(tallies, poll), orientacao_do_governo: government[poll.id],
        temas: poll.themes.map(&:name),
        projetos: poll.bills.map { |bill| "#{bill.bill_type} #{bill.number}/#{bill.year}" }.presence,
        votos_da_bancada: (tally(party_tallies, poll).presence || "a bancada não votou" if party_tallies),
        orientacao_da_lideranca: orientations&.dig(poll.id)
      }.compact
    end
  end

  # { "Sim" => 300, "Não" => 120 } de uma votação, na ordem das páginas
  def tally(counts, poll)
    votes = counts.filter_map { |(poll_id, vote), count| [vote, count] if poll_id == poll.id }.to_h
    votes.sort_by { |vote, _| DeputyOverview::VOTE_ORDER.index(vote) || DeputyOverview::VOTE_ORDER.size }.to_h
  end

  # Votos dos deputados que hoje estão no partido (como na aba Votações do partido)
  def party_votes
    Vote.joins(:deputy).where(deputies: { party_id: @filters[:party].id })
  end

  def notes
    [(government_note if @filters[:government]), (party_note if @filters[:party])].compact.join(" ").presence
  end

  def government_note
    "O Governo vence quando o resultado oficial coincide com a orientação dele (Sim ou Não) e perde quando não " \
      "coincide; votações em que ele não orientou Sim ou Não, sem resultado oficial ou de manutenção do texto " \
      "não entram."
  end

  def party_note
    "Votos da bancada pelo partido atual de cada deputado: quem trocou de legenda conta no partido novo. " \
      "A orientação é a da liderança do partido ou, quando ele orienta pela federação, a da federação."
  end

  # Continuação (página de votações com os mesmos filtros), a primeira votação
  # e, com partido, a aba Votações do partido
  def next_steps(polls, total)
    return if polls.empty?

    first = polls.first
    [
      *continuation(shown: polls.size, total: total, max: MAX_LIMIT,
                    description: "#{"votações #{filters_text}".strip}, das mais recentes para as mais antigas",
                    last: polls.last.date&.strftime("%d/%m/%Y"), page: page_path),
      link("Ver votação de #{first.date&.strftime('%d/%m/%Y')}", routes.poll_path(first)),
      (if @filters[:party]
         link("Ver votações do #{@filters[:party].label}",
              routes.party_path(@filters[:party], tab: "votes"))
       end)
    ].compact
  end

  # "em que o Governo perdeu, sobre Saúde, com o voto do PT, de 2025, aprovadas, com o termo 'urgência'"
  def filters_text
    theme, party, year, result, government, query = @filters.values_at(:theme, :party, :year, :result, :government,
                                                                       :query)
    [("em que o Governo #{government}" if government), ("sobre #{theme.name}" if theme),
     ("com o voto do #{party.label}" if party), ("de #{year}" if year), RESULT_LABELS[result],
     ("com o termo '#{query}'" if query)].compact.join(", ")
  end

  # Página de votações com os mesmos filtros (mesmos parâmetros de PollsController)
  def page_path
    routes.polls_path({ q: @filters[:query], year: @filters[:year], theme: @filters[:theme]&.id,
                        approval: RESULTS[@filters[:result]], governo: @filters[:government] }.compact)
  end
end
