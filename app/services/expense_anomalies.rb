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

  SEVERITIES = %i[high medium low].freeze

  def initialize(deputy)
    @deputy = deputy
  end

  # [{ kind:, severity:, value:, reference:, expense_type:, month:, supplier:, count:, expense_ids: }]
  # (só as chaves que fazem sentido para cada tipo de anomalia)
  def for_year(year)
    @year = year
    [
      *duplicate_documents, *split_notes, *atypical_notes,
      *month_peaks, *type_jumps, *exclusive_suppliers, *new_suppliers
    ].sort_by { |row| [SEVERITIES.index(row[:severity]), -row[:value].to_f] }
  end

  # { tipo => valor da nota no percentil NOTE_PERCENTILE } na Câmara toda
  def self.note_limits(year)
    percentile = ActiveRecord::Base.sanitize_sql_array(["PERCENTILE_CONT(?) WITHIN GROUP (ORDER BY net_amount)", NOTE_PERCENTILE])
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
      next unless previous.positive? && value >= previous * TYPE_JUMP_FACTOR && value - previous >= TYPE_JUMP_MIN_INCREASE

      { kind: :type_jump, severity: :low, expense_type: type, value: value, reference: previous }
    end
  end

  # Empresas que só aparecem nas notas deste deputado e receberam muito
  def exclusive_suppliers
    totals = with_supplier_document.where("LENGTH(REGEXP_REPLACE(supplier_cnpj_cpf, '\\D', '', 'g')) = 14")
                                   .group(:supplier_cnpj_cpf).having("SUM(net_amount) >= ?", EXCLUSIVE_SUPPLIER_MIN)
                                   .pluck(:supplier_cnpj_cpf, Arel.sql("MIN(supplier)"), Arel.sql("SUM(net_amount)"))
    return [] if totals.empty?

    clients = Expense.where(supplier_cnpj_cpf: totals.map(&:first)).group(:supplier_cnpj_cpf).distinct.count(:deputy_id)
    totals.select { |document, _, _| clients[document] == 1 }.map do |_, supplier, value|
      { kind: :exclusive_supplier, severity: :low, supplier: supplier, value: value }
    end
  end

  # Fornecedores que não atendiam o deputado no ano anterior e já receberam muito
  def new_suppliers
    previous = @deputy.expenses.where(year: @year - 1).where.not(supplier_cnpj_cpf: [nil, ""]).distinct.pluck(:supplier_cnpj_cpf)
    return [] if previous.empty?

    with_supplier_document.where.not(supplier_cnpj_cpf: previous)
                          .group(:supplier_cnpj_cpf).having("SUM(net_amount) >= ?", NEW_SUPPLIER_MIN)
                          .pluck(Arel.sql("MIN(supplier)"), Arel.sql("SUM(net_amount)"))
                          .map { |supplier, value| { kind: :new_supplier, severity: :low, supplier: supplier, value: value } }
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
  end
end
