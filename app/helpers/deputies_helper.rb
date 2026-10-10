module DeputiesHelper
  MONTHS = %w[Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez].freeze
  VOTE_BADGES = {
    "Sim"        => "text-bg-success",
    "Não"        => "text-bg-danger",
    "Abstenção"  => "text-bg-secondary",
    "Obstrução"  => "text-bg-warning",
    "Artigo 17"  => "text-bg-light border"
  }.freeze
  VOTE_EXPLANATIONS = {
    "Abstenção" => "Registrou presença, mas não votou Sim nem Não.",
    "Obstrução" => "Recurso para atrasar a votação: o deputado conta como ausente para o quórum.",
    "Artigo 17" => "Art. 17 do Regimento Interno: quem preside a sessão não vota, exceto para desempatar."
  }.freeze

  def brl(value, precision: 2)
    number_to_currency(value || 0, unit: "R$ ", separator: ",", delimiter: ".", precision: precision)
  end

  def percent(value)
    value.nil? ? "—" : "#{value}%"
  end

  def month_label(month)
    MONTHS[month.to_i - 1] if month.to_i.between?(1, 12)
  end

  # Página de gastos da Câmara já filtrada pelo deputado, ano e (opcional) mês.
  # Legislaturas de 4 anos: a 57ª começou em 2023
  def camara_expenses_url(deputy, year, month = nil)
    params = { legislatura: 57 + ((year - 2023) / 4), ano: year, mes: month_label(month)&.upcase,
               por: "deputado", deputado: deputy.json_id }.compact
    "https://www.camara.leg.br/transparencia/gastos-parlamentares?#{params.to_query}"
  end

  def vote_badge_class(vote)
    VOTE_BADGES.fetch(vote, "text-bg-light border")
  end

  def vote_explanation(vote)
    VOTE_EXPLANATIONS[vote]
  end

  # Ícone "ⓘ" com a explicação de como o indicador é calculado.
  # Funciona com teclado e toque (tooltip do Bootstrap) e cai no `title` sem JS.
  def info_tip(text)
    tag.span(class: "info-tip text-muted ms-1", tabindex: 0, role: "button", title: text,
             aria: { label: "Como calculamos: #{text}" }, data: { controller: "tooltip" }) do
      tag.i(class: "fa-solid fa-circle-info", aria: { hidden: true })
    end
  end

  # CPF de fornecedor pessoa física é dado pessoal (LGPD): mostra só os dígitos do meio
  def supplier_document(document)
    digits = document.to_s.gsub(/\D/, "")
    return document.presence || "—" unless digits.size == 11

    "***.#{digits[3, 3]}.#{digits[6, 3]}-**"
  end

  # Links de redes sociais válidos (http/https), ignorando URLs malformadas
  def social_links(deputy)
    deputy.social_media.to_s.split.filter_map do |url|
      uri = URI.parse(url)
      next unless uri.is_a?(URI::HTTP) && uri.host.present?

      [url, uri.host.sub(/\Awww\./, "")]
    rescue URI::InvalidURIError
      nil
    end
  end

  # Diferença percentual entre o valor e a média (ex.: +35%)
  def compared_to_average(value, average)
    return if average.to_f.zero?

    diff = ((value.to_f - average.to_f) / average.to_f * 100).round
    word = diff.positive? ? "acima" : "abaixo"
    diff.zero? ? "igual à média" : "#{diff.abs}% #{word} da média"
  end

  def expense_type_label(type)
    type.to_s.capitalize.delete_suffix(".")
  end

  def deputy_tab_path(deputy, tab, extra = {})
    deputy_path(deputy, { tab: tab }.merge(extra.compact))
  end

  # [título, explicação do critério] de um item de ExpenseAnomalies
  def expense_anomaly_text(row)
    supplier = row[:supplier].presence || "fornecedor não informado"
    case row[:kind]
    when :duplicate_document
      ["A mesma nota aparece #{row[:count]} vezes: #{supplier}, #{brl(row[:value])} no total",
       "Notas com o mesmo link de documento lançadas mais de uma vez."]
    when :split_notes
      ["#{row[:count]} notas de #{supplier} no mesmo dia (#{row[:date]&.strftime('%d/%m/%Y')}), somando #{brl(row[:value])}",
       "#{ExpenseAnomalies::SPLIT_MIN_NOTES} ou mais notas do mesmo fornecedor no mesmo dia, somando ao menos #{brl(ExpenseAnomalies::SPLIT_MIN_TOTAL, precision: 0)}."]
    when :atypical_note
      ["#{pluralize(row[:count], 'nota', plural: 'notas')} de #{expense_type_label(row[:expense_type]).downcase} acima de #{brl(row[:reference], precision: 0)}",
       "Valor maior que o de #{(ExpenseAnomalies::NOTE_PERCENTILE * 100).to_s.tr('.', ',').delete_suffix(',0')}% das notas do mesmo tipo na Câmara no ano."]
    when :month_peak
      ["#{month_label(row[:month])}: #{brl(row[:value], precision: 0)}, #{(row[:value] / row[:reference]).round(1).to_s.tr('.', ',')}× o mês típico do deputado",
       "Mês com gasto acima de #{ExpenseAnomalies::MONTH_PEAK_FACTOR.to_s.tr('.', ',')}× a mediana mensal do próprio deputado (#{brl(row[:reference], precision: 0)})."]
    when :type_jump
      ["#{expense_type_label(row[:expense_type])}: de #{brl(row[:reference], precision: 0)} para #{brl(row[:value], precision: 0)}",
       "Tipo de despesa que pelo menos dobrou em relação ao mesmo período do ano anterior."]
    when :exclusive_supplier
      ["#{supplier} só aparece nas notas deste deputado e recebeu #{brl(row[:value], precision: 0)}",
       "Empresa que não atende nenhum outro deputado e recebeu ao menos #{brl(ExpenseAnomalies::EXCLUSIVE_SUPPLIER_MIN, precision: 0)} no ano."]
    when :new_supplier
      ["#{supplier} é fornecedor novo e já recebeu #{brl(row[:value], precision: 0)}",
       "Fornecedor que não aparecia nas notas do ano anterior e já recebeu ao menos #{brl(ExpenseAnomalies::NEW_SUPPLIER_MIN, precision: 0)}."]
    end
  end

  def compare_value(row, cell)
    value = cell[:value]
    return "—" if value.nil?

    case row.format
    when :currency then brl(value)
    when :percent  then percent(value)
    else value.to_s
    end
  end
end
