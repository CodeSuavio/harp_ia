# Gastos de um deputado que fogem do padrão: do próprio histórico (mês a mês,
# ano a ano) ou da Câmara (notas e fornecedores). Não indicam irregularidade,
# só o que merece um olhar mais atento.
#
# Os percentuais nos comentários são a fatia de deputados marcados por cada regra
# nos dados de 2025 (490 deputados com despesas).
class ExpenseAnomalies
  # Mês com gasto acima de 2,5× a mediana mensal do próprio deputado (~11%)
  MONTH_PEAK_FACTOR = 2.5
  # Com poucos meses a mediana não diz muito
  MONTH_PEAK_MIN_MONTHS = 4
  # Tipo de despesa que pelo menos dobrou em relação ao mesmo período do ano anterior
  # e cresceu ao menos esse valor (evita alertas de R$ 100 → R$ 300). Sem dados de
  # 2024 ainda, limiares não calibrados
  TYPE_JUMP_FACTOR = 2
  TYPE_JUMP_MIN_INCREASE = 20_000
  # Fornecedor que não aparecia no ano anterior e já recebeu pelo menos isso (idem)
  NEW_SUPPLIER_MIN = 50_000
  # Nota acima do percentil 99,5 do mesmo tipo na Câmara (~17%; com 99% seriam 24%)
  NOTE_PERCENTILE = 0.995
  # Empresa (CNPJ) que só atende este deputado e recebeu ao menos isso no ano (~8%).
  # Com R$ 100 mil seriam 44%: aluguel de carro e divulgação costumam ser exclusivos
  EXCLUSIVE_SUPPLIER_MIN = 200_000
  # Várias notas do mesmo fornecedor no mesmo dia (~4%). Com 3 notas seriam 16%
  SPLIT_MIN_NOTES = 4
  SPLIT_MIN_TOTAL = 5_000
  # Empresa sem atividade compatível com o tipo de despesa: gravidade alta quando
  # o deputado pagou ao menos isso a ela no ano
  INCOMPATIBLE_HIGH_MIN = 5_000

  # Atividades (CNAE) compatíveis com cada tipo de despesa, por divisão ("73") ou
  # grupo ("47.3"). A empresa é compatível se a atividade principal OU alguma
  # secundária começar com um desses códigos. Tipos fora da lista não geram alerta.
  # A base não traz os itens da nota, então a comparação é só tipo × atividade.
  ACTIVITY_RULES = {
    # Postos (47.3), distribuidoras (46.8), troca de óleo e autopeças (45.2, 45.3)
    "COMBUSTÍVEIS E LUBRIFICANTES." => %w[47.3 46.8 45.2 45.3],
    # Publicidade (73), gráficas (18), editoras, audiovisual, rádio e TV (58, 59, 60), sites,
    # portais e TI (62, 63), design e fotografia (74), eventos e disparo de mensagens (82, 61), artes (90)
    "DIVULGAÇÃO DA ATIVIDADE PARLAMENTAR." => %w[73 18 58 59 60 61 62 63 74 82 90],
    # Comércio (46, 47), obras e reparos (43), aluguel e condomínio (68, 81), locação de
    # equipamentos (77), consertos (33, 95), energia, água, internet e software (35, 36, 61, 62, 63),
    # serviços de escritório (82), seguros (65) e tributos municipais (84)
    "MANUTENÇÃO DE ESCRITÓRIO DE APOIO À ATIVIDADE PARLAMENTAR" =>
      %w[46 47 43 68 81 77 33 95 35 36 61 62 63 82 65 84],
    # Locadoras (77.1), transporte rodoviário (49), concessionárias (45.1), agências de viagem (79)
    "LOCAÇÃO OU FRETAMENTO DE VEÍCULOS AUTOMOTORES" => %w[77.1 49 45.1 79],
    "LOCAÇÃO OU FRETAMENTO DE AERONAVES" => %w[51 52.4 77.3 79],
    "LOCAÇÃO OU FRETAMENTO DE EMBARCAÇÕES" => %w[50 77.3 79],
    # Restaurantes (56), padarias e mercados (47.1, 47.2), hotéis (55)
    "FORNECIMENTO DE ALIMENTAÇÃO DO PARLAMENTAR" => %w[56 47.1 47.2 55],
    "HOSPEDAGEM ,EXCETO DO PARLAMENTAR NO DISTRITO FEDERAL." => %w[55 79 68],
    # Táxi e transporte (49), pedágio e estacionamento (52.2), aplicativos (62, 63, 74.9)
    "SERVIÇO DE TÁXI, PEDÁGIO E ESTACIONAMENTO" => %w[49 52.2 62 63 74.9],
    "SERVIÇO DE SEGURANÇA PRESTADO POR EMPRESA ESPECIALIZADA." => %w[80],
    "SERVIÇOS POSTAIS" => %w[53 82],
    "ASSINATURA DE PUBLICAÇÕES" => %w[58 63 60 47.6],
    "PASSAGENS TERRESTRES, MARÍTIMAS OU FLUVIAIS" => %w[49 50 79],
    "PARTICIPAÇÃO EM CURSO, PALESTRA OU EVENTO SIMILAR" => %w[85 82.3 94 70 72],
    "COMPLEMENTAÇÃO DO AUXÍLIO-MORADIA" => %w[68 55],
    "AQUISIÇÃO DE TOKENS E CERTIFICADOS DIGITAIS" => %w[62 63 82 66]
  }.transform_values { |codes| codes.map { |code| code.delete(".") }.freeze }.freeze

  # Nota de empresa (CNPJ) com o cadastro já consultado
  CompanyNote = Data.define(:id, :expense_type, :supplier, :value, :date, :company)

  SEVERITIES = %i[high medium low].freeze

  def initialize(deputy)
    @deputy = deputy
  end

  # [{ kind:, severity:, value:, reference:, expense_type:, month:, supplier:, count:, expense_ids:, cnae: }]
  # (só as chaves que fazem sentido para cada tipo de anomalia)
  def for_year(year)
    @year = year
    @company_notes = nil
    [
      *duplicate_documents, *split_notes, *atypical_notes, *incompatible_activities, *inactive_suppliers,
      *month_peaks, *type_jumps, *exclusive_suppliers, *new_suppliers
    ].sort_by { |row| [SEVERITIES.index(row[:severity]), -row[:value].to_f] }
  end

  # { tipo => valor da nota no percentil NOTE_PERCENTILE } na Câmara toda
  def self.note_limits(year)
    percentile = ActiveRecord::Base.sanitize_sql_array(["PERCENTILE_CONT(?) WITHIN GROUP (ORDER BY net_amount)",
                                                        NOTE_PERCENTILE])
    DeputyMetrics.cached("note-limits/#{year}", Expense) do
      Expense.where(year: year).where("net_amount > 0").group(:expense_type)
             .pluck(:expense_type, Arel.sql(percentile))
             .to_h { |type, value| [type, value.to_d] }
    end
  end

  private

  def expenses
    @deputy.expenses.where(year: @year)
  end

  # Notas com valor, sem passagens aéreas e telefonia (concentradas por natureza)
  def notes
    scope = expenses.where("net_amount > 0")
    DeputyStats::CONCENTRATION_IGNORED_TYPES.each { |type| scope = scope.where.not("expense_type LIKE ?", type) }
    scope
  end

  def with_supplier_document
    notes.where.not(supplier_cnpj_cpf: [nil, ""])
  end

  # A mesma nota (mesmo link do documento) lançada mais de uma vez
  def duplicate_documents
    notes.where.not(document_url: [nil, ""]).group(:document_url).having("COUNT(*) > 1")
         .pluck(Arel.sql("MIN(supplier)"), Arel.sql("MIN(month)"), Arel.sql("SUM(net_amount)"), Arel.sql("ARRAY_AGG(id)"))
         .map do |supplier, month, value, ids|
           { kind: :duplicate_document, severity: :high, supplier: supplier, month: month,
             value: value, count: ids.size, expense_ids: ids }
         end
  end

  # Muitas notas do mesmo fornecedor no mesmo dia, que juntas somam um valor alto
  def split_notes
    with_supplier_document.group(:supplier_cnpj_cpf, Arel.sql("DATE(document_date)"))
                          .having("COUNT(*) >= ? AND SUM(net_amount) >= ?", SPLIT_MIN_NOTES, SPLIT_MIN_TOTAL)
                          .pluck(Arel.sql("MIN(supplier)"), Arel.sql("DATE(document_date)"), Arel.sql("SUM(net_amount)"), Arel.sql("ARRAY_AGG(id)"))
                          .map do |supplier, date, value, ids|
                            { kind: :split_notes, severity: :medium, supplier: supplier, date: date, month: date&.month,
                              value: value, count: ids.size, expense_ids: ids }
                          end
  end

  # Notas mais caras que quase todas as do mesmo tipo na Câmara (agrupadas por tipo)
  def atypical_notes
    limits = self.class.note_limits(@year)
    notes.pluck(:id, :expense_type, :net_amount)
         .select { |_, type, value| limits[type] && value > limits[type] }
         .group_by { |_, type, _| type }
         .map do |type, rows|
           { kind: :atypical_note, severity: :high, expense_type: type, value: rows.sum(&:last),
             reference: limits[type], count: rows.size, expense_ids: rows.map(&:first) }
         end
  end

  # Meses em que o deputado gastou bem mais que o normal dele
  def month_peaks
    monthly = expenses.group(:month).sum(:net_amount)
    return [] if monthly.size < MONTH_PEAK_MIN_MONTHS

    typical = median(monthly.values)
    return [] unless typical.positive?

    monthly.select { |_, value| value > typical * MONTH_PEAK_FACTOR }.map do |month, value|
      { kind: :month_peak, severity: :medium, month: month, value: value, reference: typical }
    end
  end

  # Tipos de despesa que cresceram muito em relação ao mesmo período do ano anterior
  def type_jumps
    last_month = Expense.where(year: @year).maximum(:month)
    before = @deputy.expenses.where(year: @year - 1, month: ..last_month.to_i).group(:expense_type).sum(:net_amount)
    return [] if before.empty?

    expenses.group(:expense_type).sum(:net_amount).filter_map do |type, value|
      previous = before[type].to_d
      unless previous.positive? && value >= previous * TYPE_JUMP_FACTOR && value - previous >= TYPE_JUMP_MIN_INCREASE
        next
      end

      { kind: :type_jump, severity: :low, expense_type: type, value: value, reference: previous }
    end
  end

  # Empresas que só aparecem nas notas deste deputado e receberam muito
  def exclusive_suppliers
    totals = notes.with_cnpj.group(:supplier_cnpj_cpf).having("SUM(net_amount) >= ?", EXCLUSIVE_SUPPLIER_MIN)
                  .pluck(:supplier_cnpj_cpf, Arel.sql("MIN(supplier)"), Arel.sql("SUM(net_amount)"))
    return [] if totals.empty?

    clients = Expense.where(supplier_cnpj_cpf: totals.map(&:first)).group(:supplier_cnpj_cpf).distinct.count(:deputy_id)
    totals.select { |document, _, _| clients[document] == 1 }.map do |_, supplier, value|
      { kind: :exclusive_supplier, severity: :low, supplier: supplier, value: value }
    end
  end

  # Fornecedores que não atendiam o deputado no ano anterior e já receberam muito
  def new_suppliers
    previous = @deputy.expenses.where(year: @year - 1).where.not(supplier_cnpj_cpf: [nil,
                                                                                     ""]).distinct.pluck(:supplier_cnpj_cpf)
    return [] if previous.empty?

    with_supplier_document.where.not(supplier_cnpj_cpf: previous)
                          .group(:supplier_cnpj_cpf).having("SUM(net_amount) >= ?", NEW_SUPPLIER_MIN)
                          .pluck(Arel.sql("MIN(supplier)"), Arel.sql("SUM(net_amount)"))
                          .map do |supplier, value|
      { kind: :new_supplier, severity: :low, supplier: supplier,
        value: value }
    end
  end

  # Empresas sem nenhuma atividade (principal ou secundária) compatível com o tipo
  # de despesa, agrupadas por fornecedor e tipo
  def incompatible_activities
    totals = company_notes.group_by { |note| note.company.cnpj }.transform_values { |notes| notes.sum(&:value) }

    company_notes.select { |note| incompatible?(note) }
                 .group_by { |note| [note.company.cnpj, note.expense_type] }
                 .map do |(cnpj, type), notes|
                   severity = totals[cnpj] >= INCOMPATIBLE_HIGH_MIN ? :high : :medium
                   company_alert(:incompatible_supplier_activity, severity, notes).merge(expense_type: type)
                 end
  end

  def incompatible?(note)
    codes = ACTIVITY_RULES[note.expense_type]
    codes.present? && !note.company.activity_in?(codes)
  end

  # Notas emitidas quando a empresa já não estava ATIVA na Receita (baixada, inapta, suspensa)
  def inactive_suppliers
    company_notes.select { |note| note.company.inactive_on?(note.date) }
                 .group_by { |note| note.company.cnpj }
                 .map do |_, notes|
                   company = notes.first.company
                   company_alert(:inactive_supplier, :high, notes)
                     .merge(status: company.registration_status, status_date: company.registration_status_date)
                 end
  end

  def company_alert(kind, severity, notes)
    company = notes.first.company
    { kind: kind, severity: severity, supplier: notes.first.supplier, value: notes.sum(&:value),
      count: notes.size, expense_ids: notes.map(&:id),
      cnae: { code: Supplier.format_cnae(company.cnae_code), description: company.cnae_description } }
  end

  def company_notes
    @company_notes ||= begin
      rows = notes.with_cnpj
                  .pluck(:id, :expense_type, :supplier, :net_amount, :document_date, Expense::DOCUMENT_DIGITS)
      companies = Supplier.with_activity.where(cnpj: rows.map(&:last).uniq).index_by(&:cnpj)
      rows.filter_map { |*fields, cnpj| CompanyNote.new(*fields, companies[cnpj]) if companies[cnpj] }
    end
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
  end
end
