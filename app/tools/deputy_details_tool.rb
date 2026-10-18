# Perfil e indicadores de um deputado, com os mesmos cálculos exibidos nas
# abas do perfil (gastos, votações, projetos e promessas × atuação).
#
# Com section, traz uma seção do perfil com os mesmos dados da página
# (PageSections::DEPUTY): os serviços DeputyExpenseBreakdown e
# DeputyVoteHistory são os mesmos que as abas usam.
class DeputyDetailsTool < ApplicationTool # rubocop:disable Metrics/ClassLength -- perfil e seções das abas
  # section => [aba, seção em PageSections::DEPUTY]
  SECTIONS = {
    "gastos_por_mes" => %w[expenses monthly],
    "fornecedores" => %w[expenses suppliers],
    "despesas" => %w[expenses notes],
    "votacoes_por_tema" => %w[votes vote_themes],
    "votacoes_recentes" => %w[votes vote_history],
    "historico_de_partidos" => %w[overview party_history]
  }.freeze
  # Itens das listas de notas e de votos (as páginas mostram todos, em páginas)
  LIST_ITEMS = 10

  description <<~DESC
    Retorna o perfil e as análises de um deputado federal: gastos da cota
    parlamentar (total, média mensal, uso da cota, ranking, comparação com
    estado e partido, gastos por tipo e alertas de gastos atípicos com o
    critério de cada alerta), participação nas votações, alinhamento com o
    partido, projetos de lei e coerência entre promessas e votos.
    Com section, traz uma seção do perfil:
    #{SECTIONS.map { |key, (tab, id)| "#{key} (#{PageSections::DEPUTY.dig(tab, id, :title)})" }.join(', ')}.
  DESC

  param :deputy_id, type: "integer", desc: "Id do deputado"
  param :year, type: "integer", desc: "Ano dos gastos (opcional; padrão: ano mais recente com dados)", required: false
  param :section, desc: "Seção do perfil (opcional): #{SECTIONS.keys.join(', ')}", required: false

  def execute(deputy_id:, year: nil, section: nil)
    deputy = Deputy.includes(:party).find_by(id: deputy_id)
    return not_found("Deputado") unless deputy
    return invalid_section if section && !SECTIONS.key?(section)

    cite_deputy(deputy)
    cite_party(deputy.party)

    year = expense_year(deputy, year)
    return section_result(deputy, section, year) if section

    stats = DeputyStats.new(deputy)
    profile = DeputyThemeProfile.new(deputy)
    alerts = year ? ExpenseAnomalies.new(deputy).for_year(year) : []
    candidate = deputy.candidates.first

    {
      deputado: {
        id: deputy.id,
        nome: deputy.name,
        partido: party_label(deputy),
        uf: deputy.state_label,
        situacao: deputy.status,
        condicao_eleitoral: deputy.electoral_status,
        escolaridade: deputy.education_level,
        naturalidade: [deputy.city_of_birth, deputy.state_of_birth].compact.join("-").presence
      },
      anos_com_gastos: expense_years(deputy),
      gastos: year && expenses(deputy, stats, year, alerts),
      votacoes: {
        participacao: stats.vote_participation,
        alinhamento_com_partido: stats.party_alignment,
        votos_por_tipo: deputy.votes.group(:vote).count
      },
      projetos_de_lei: {
        total: deputy.bills.count,
        media_por_deputado_na_camara: DeputyMetrics.average_bills,
        temas_principais: profile.top_themes,
        recentes: deputy.bills.order(Arel.sql("submission_date DESC NULLS LAST")).limit(5).map do |bill|
          { id: bill.id, numero: "#{bill.bill_type} #{bill.number}/#{bill.year}",
            ementa: bill.summary.to_s.truncate(200) }
        end
      },
      promessas_x_atuacao: {
        coerencia: profile.coherence,
        explicacao: "Coerência = votos Sim/Não do deputado no sentido que cumpre as propostas ligadas a ele " \
                    "(dele e do partido). Com menos de #{DeputyThemeProfile::MIN_EVIDENCE} votos avaliados, " \
                    "o indicador é pouco conclusivo."
      },
      candidatura_2026: candidate&.then do |c|
        { id: c.id, nome_de_urna: c.ballot_name, situacao: c.candidacy_status }
      end,
      acoes: next_steps(deputy, year, alerts, candidate)
    }
  end

  private

  # O ano pedido, se tiver gastos; senão, o mais recente com gastos
  def expense_year(deputy, year)
    years = expense_years(deputy)
    years.include?(year.to_i) ? year.to_i : years.first
  end

  def expense_years(deputy)
    deputy.expenses.distinct.order(year: :desc).pluck(:year)
  end

  def invalid_section = { erro: "Seção inválida. Use uma destas: #{SECTIONS.keys.join(', ')}." }

  # ----- SEÇÕES DO PERFIL -----

  def section_result(deputy, section, year)
    tab, id = SECTIONS.fetch(section)
    info = PageSections::DEPUTY.dig(tab, id)
    {
      deputado: { id: deputy.id, nome: deputy.name, partido: party_label(deputy), uf: deputy.state_label },
      secao: info[:title],
      o_que_mostra: info[:chart],
      **send(section, deputy, year),
      acoes: [link("Ver aba #{DeputiesController::TABS[tab]}",
                   routes.deputy_path(deputy, tab: tab, year: (year if tab == "expenses")))]
    }
  end

  def expenses_of(deputy, year)
    DeputyExpenseBreakdown.new(deputy.expenses.where(year: year))
  end

  # Os 12 meses do ano, como as barras da página (meses sem despesa valem 0)
  def gastos_por_mes(deputy, year)
    return { aviso: "Nenhum gasto registrado." } unless year

    monthly = expenses_of(deputy, year).monthly
    { ano: year, meses: (1..12).map { |month| { mes: helpers.month_label(month), valor: money(monthly[month].to_f) } },
      total_do_ano: money(monthly.values.sum) }
  end

  def fornecedores(deputy, year)
    return { aviso: "Nenhum gasto registrado." } unless year

    {
      ano: year,
      concentracao_no_principal_fornecedor: DeputyStats.new(deputy).supplier_concentration(year: year),
      fornecedores: expenses_of(deputy, year).top_suppliers.map do |supplier, document, total, count|
        { fornecedor: supplier.presence || "Não informado", cnpj_cpf: helpers.supplier_document(document),
          notas: count, total: money(total) }
      end,
      observacao: "CPFs de pessoas físicas aparecem parcialmente ocultos, como na página."
    }
  end

  def despesas(deputy, year)
    return { aviso: "Nenhum gasto registrado." } unless year

    notes = expenses_of(deputy, year).notes
    {
      ano: year,
      total_de_notas: notes.count,
      mais_recentes: notes.limit(LIST_ITEMS).map do |expense|
        { data: expense.document_date&.to_date, tipo: helpers.expense_type_label(expense.expense_type),
          fornecedor: expense.supplier, valor: money(expense.net_amount) }
      end
    }
  end

  # Na ordem da página: o tema com mais votações primeiro
  def votacoes_por_tema(deputy, _year)
    themes = DeputyVoteHistory.new(deputy).themes.sort_by { |_, count| -count }
    { como_e_calculado: "tema do projeto de lei votado, classificado automaticamente por palavras-chave; " \
                        "votações sem projeto vinculado ficam de fora.",
      temas: themes.map { |theme, count| { tema: theme.name, votacoes: count } } }
  end

  def votacoes_recentes(deputy, _year)
    history = DeputyVoteHistory.new(deputy)
    votes = history.votes.limit(LIST_ITEMS).to_a
    majorities = history.majorities(votes.map(&:poll_id))
    {
      total_de_votos: history.votes.count,
      votos_contra_o_partido: history.against_party_ids.size,
      mais_recentes: votes.map { |vote| vote_row(vote, majorities[vote.poll_id]) }
    }
  end

  # Como a tabela da aba: com ou contra o partido só nos votos Sim/Não com maioria do partido
  def vote_row(vote, majority)
    poll = vote.poll
    {
      data: poll.date&.to_date, votacao: poll.description.to_s.truncate(160),
      proposicoes: poll.bills.map { |bill| helpers.proposicao_label(bill) }.presence,
      voto: vote.vote, maioria_do_partido: majority,
      com_o_partido: (majority == vote.vote if majority && Vote::DECISIVE.include?(vote.vote))
    }.compact
  end

  def historico_de_partidos(deputy, _year)
    affiliations = deputy.party_affiliations.includes(:party).to_a
    return { aviso: "Sem histórico de partidos registrado para este deputado." } if affiliations.empty?

    changes = affiliations.count { |item| item.change? && item.party_label != PartiesHelper::NO_PARTY_LABEL }
    {
      trocas_de_partido: changes,
      desde: affiliations.first.started_on.year,
      periodos: affiliations.each_with_index.map do |affiliation, index|
        { desde: affiliation.started_on, partido: affiliation_label(affiliation),
          evento: helpers.affiliation_event(affiliation, affiliations[index - 1]) }
      end,
      como_e_calculado: "partido em cada período como deputado federal, segundo o histórico da Câmara; mudanças " \
                        "de nome e fusões não contam como troca."
    }
  end

  def affiliation_label(affiliation)
    affiliation.party_label == PartiesHelper::NO_PARTY_LABEL ? "Sem partido" : affiliation.party_label
  end

  # Abas do perfil com o que foi resumido aqui e consultas ligadas ao deputado
  def next_steps(deputy, year, alerts, candidate)
    party = party_label(deputy)
    [
      link("Ver perfil de #{deputy.name}", routes.deputy_path(deputy)),
      (if alerts.any?
         link("Ver notas com alerta", routes.deputy_path(deputy, tab: "expenses", year: year, alerts: "1"))
       end),
      (link("Ver projetos de lei", routes.deputy_path(deputy, tab: "bills")) if deputy.authored_bills.exists?),
      link("Ver votações", routes.deputy_path(deputy, tab: "votes")),
      (link("Ver candidatura 2026", routes.candidate_path(candidate)) if candidate),
      (if year
         question("Gastos dos deputados de #{deputy.state_label}",
                  "Quais deputados de #{deputy.state_label} têm o maior gasto mensal?")
       end),
      (question("Sobre o #{party}", "Mostre os dados do partido #{party}") if party)
    ].compact
  end

  def expenses(deputy, stats, year, alerts)
    {
      ano: year,
      total: money(stats.total_expenses(year: year)),
      media_mensal: money(stats.monthly_average(year: year)),
      media_mensal_do_estado_e_do_partido: stats.expense_benchmarks(year: year).transform_values { |v| money(v) },
      uso_da_cota: DeputyMetrics.quota_usage(deputy, year),
      ranking_gasto_mensal: DeputyMetrics.expense_rank(deputy, year),
      variacao_ano_anterior: stats.year_over_year(year: year),
      concentracao_no_principal_fornecedor: stats.supplier_concentration(year: year),
      por_tipo: stats.expenses_by_type(year: year).first(8),
      alertas: alerts.first(LIST_LIMIT).map do |row|
        title, criterion = helpers.expense_anomaly_text(row)
        { gravidade: row[:severity], alerta: title, criterio: criterion }
      end,
      observacao: "Alertas indicam gastos fora do padrão segundo critérios estatísticos; não são prova de irregularidade."
    }
  end
end
