# Perfil e indicadores de um deputado, com os mesmos cálculos exibidos nas
# abas do perfil (gastos, votações, projetos e promessas × atuação).
class DeputyDetailsTool < ApplicationTool
  description <<~DESC
    Retorna o perfil e as análises de um deputado federal: gastos da cota
    parlamentar (total, média mensal, uso da cota, ranking, comparação com
    estado e partido, gastos por tipo e alertas de gastos atípicos com o
    critério de cada alerta), participação nas votações, alinhamento com o
    partido, projetos de lei e coerência entre promessas e votos.
  DESC

  param :deputy_id, type: "integer", desc: "Id do deputado"
  param :year, type: "integer", desc: "Ano dos gastos (opcional; padrão: ano mais recente com dados)", required: false

  def execute(deputy_id:, year: nil)
    deputy = Deputy.includes(:party).find_by(id: deputy_id)
    return not_found("Deputado") unless deputy

    stats = DeputyStats.new(deputy)
    years = deputy.expenses.distinct.order(year: :desc).pluck(:year)
    year = years.include?(year.to_i) ? year.to_i : years.first
    profile = DeputyThemeProfile.new(deputy)

    {
      deputado: {
        id: deputy.id,
        nome: deputy.name,
        partido: party_label(deputy),
        uf: deputy.state_label,
        situacao: deputy.status,
        condicao_eleitoral: deputy.electoral_status,
        escolaridade: deputy.education_level,
        naturalidade: [deputy.city_of_birth, deputy.state_of_birth].compact.join("-").presence,
        pagina: routes.deputy_path(deputy)
      },
      anos_com_gastos: years,
      gastos: year && expenses(deputy, stats, year),
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
          { id: bill.id, numero: "#{bill.bill_type} #{bill.number}/#{bill.year}", ementa: bill.summary.to_s.truncate(200) }
        end
      },
      promessas_x_atuacao: {
        coerencia: profile.coherence,
        explicacao: "Coerência = votos Sim/Não do deputado no sentido que cumpre as propostas ligadas a ele " \
                    "(dele e do partido). Com menos de #{DeputyThemeProfile::MIN_EVIDENCE} votos avaliados, " \
                    "o indicador é pouco conclusivo."
      },
      candidatura_2026: deputy.candidates.first&.then { |c| { id: c.id, nome_de_urna: c.ballot_name, situacao: c.candidacy_status } }
    }
  end

  private

  def expenses(deputy, stats, year)
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
      alertas: ExpenseAnomalies.new(deputy).for_year(year).first(LIST_LIMIT).map do |row|
        title, criterion = helpers.expense_anomaly_text(row)
        { gravidade: row[:severity], alerta: title, criterio: criterion }
      end,
      observacao: "Alertas indicam gastos fora do padrão segundo critérios estatísticos; não são prova de irregularidade."
    }
  end
end
