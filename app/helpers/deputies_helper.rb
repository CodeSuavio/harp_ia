module DeputiesHelper
  MONTHS = %w[Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez].freeze
  VOTE_BADGES = {
    "Sim" => "text-bg-success",
    "Não" => "text-bg-danger",
    "Abstenção" => "text-bg-secondary",
    "Obstrução" => "text-bg-warning",
    "Artigo 17" => "text-bg-light border"
  }.freeze
  VOTE_EXPLANATIONS = {
    "Abstenção" => "Registrou presença, mas não votou Sim nem Não.",
    "Obstrução" => "Recurso para atrasar a votação: o deputado conta como ausente para o quórum.",
    "Artigo 17" => "Art. 17 do Regimento Interno: quem preside a sessão não vota, exceto para desempatar."
  }.freeze

  def brl(value, precision: 2)
    number_to_currency(value || 0, unit: "R$ ", separator: ",", delimiter: ".", precision: precision)
  end

  # Valor do indicador da ordenação que o card não mostra nas colunas fixas
  # (gasto mensal, projetos e presença), para a lista bater com o ranking da Harpia.
  def deputy_sort_value(sort, value)
    return if value.nil?

    case sort
    when "expenses_total" then "#{brl(value, precision: 0)} no ano"
    when "alignment" then "#{percent(value)} alinhado ao partido"
    when "against_party" then "#{value} #{'voto'.pluralize(value)} contra o partido"
    end
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

  # CPF de fornecedor pessoa física é dado pessoal (LGPD): mostra só os dígitos do meio.
  # CNPJ sai no formato padrão (a base traz formatações variadas, ex.: 560.310.060/0018-0)
  def supplier_document(document)
    digits = document.to_s.gsub(/\D/, "")
    case digits.size
    when 11 then "***.#{digits[3, 3]}.#{digits[6, 3]}-**"
    when 14 then "#{digits[0, 2]}.#{digits[2, 3]}.#{digits[5, 3]}/#{digits[8, 4]}-#{digits[12, 2]}"
    else document.presence || "—"
    end
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
  # Nome curto de cada tipo de alerta, para os cartões do ranking (/alertas)
  EXPENSE_ALERT_KINDS = {
    "duplicate_document" => "Nota duplicada",
    "split_notes" => "Notas fracionadas no mesmo dia",
    "atypical_note" => "Nota acima do padrão",
    "month_peak" => "Pico de gasto no mês",
    "type_jump" => "Salto em um tipo de despesa",
    "exclusive_supplier" => "Fornecedor exclusivo",
    "new_supplier" => "Fornecedor novo",
    "incompatible_supplier_activity" => "Fornecedor de outro ramo",
    "inactive_supplier" => "Fornecedor com CNPJ inativo"
  }.freeze

  def expense_alert_kind_label(kind)
    EXPENSE_ALERT_KINDS.fetch(kind.to_s, kind.to_s.humanize)
  end

  def expense_anomaly_text(row)
    supplier = row[:supplier].presence || "fornecedor não informado"
    case row[:kind]
    when :duplicate_document
      ["A mesma nota aparece #{row[:count]} vezes: #{supplier}, #{brl(row[:value])} no total",
       "Notas com o mesmo link de documento lançadas mais de uma vez."]
    when :split_notes
      ["#{row[:count]} notas de #{supplier} no mesmo dia (#{row[:date]&.strftime('%d/%m/%Y')}), somando #{brl(row[:value])}",
       "#{ExpenseAnomalies::SPLIT_MIN_NOTES} ou mais notas do mesmo fornecedor no mesmo dia, somando ao menos #{brl(
         ExpenseAnomalies::SPLIT_MIN_TOTAL, precision: 0
       )}."]
    when :atypical_note
      ["#{pluralize(row[:count], 'nota', plural: 'notas')} de #{expense_type_label(row[:expense_type]).downcase} acima de #{brl(row[:reference], precision: 0)}",
       "Valor maior que o de #{(ExpenseAnomalies::NOTE_PERCENTILE * 100).to_s.tr('.',
                                                                                 ',').delete_suffix(',0')}% das notas do mesmo tipo na Câmara no ano."]
    when :month_peak
      ["#{month_label(row[:month])}: #{brl(row[:value], precision: 0)}, #{(row[:value] / row[:reference]).round(1).to_s.tr('.', ',')}× o mês típico do deputado",
       "Mês com gasto acima de #{ExpenseAnomalies::MONTH_PEAK_FACTOR.to_s.tr('.',
                                                                             ',')}× a mediana mensal do próprio deputado (#{brl(
                                                                               row[:reference], precision: 0
                                                                             )})."]
    when :type_jump
      ["#{expense_type_label(row[:expense_type])}: de #{brl(row[:reference], precision: 0)} para #{brl(row[:value], precision: 0)}",
       "Tipo de despesa que pelo menos dobrou em relação ao mesmo período do ano anterior."]
    when :incompatible_supplier_activity
      type = expense_type_label(row[:expense_type])
      ["#{supplier}: #{brl(row[:value], precision: 0)} em #{type.downcase}, mas a empresa atua em outro ramo",
       "Empresa com atividade principal #{cnae_label(row[:cnae])}, sem atividade (principal ou secundária) " \
       "compatível com #{type} no cadastro da Receita Federal. Gravidade alta quando o fornecedor recebeu ao menos " \
       "#{brl(ExpenseAnomalies::INCOMPATIBLE_HIGH_MIN, precision: 0)} no ano."]
    when :inactive_supplier
      ["#{supplier} estava com CNPJ #{row[:status].to_s.downcase} quando emitiu " \
       "#{pluralize(row[:count], 'nota', plural: 'notas')} (#{brl(row[:value], precision: 0)})",
       "Situação cadastral na Receita Federal diferente de ATIVA desde " \
       "#{row[:status_date]&.strftime('%d/%m/%Y')}, antes da data da nota. A Receita só informa a situação " \
       "atual: uma empresa que esteve inapta e voltou a ficar ativa não aparece aqui."]
    when :exclusive_supplier
      ["#{supplier} só aparece nas notas deste deputado e recebeu #{brl(row[:value], precision: 0)}",
       "Empresa que não atende nenhum outro deputado e recebeu ao menos #{brl(ExpenseAnomalies::EXCLUSIVE_SUPPLIER_MIN,
                                                                              precision: 0)} no ano."]
    when :new_supplier
      ["#{supplier} é fornecedor novo e já recebeu #{brl(row[:value], precision: 0)}",
       "Fornecedor que não aparecia nas notas do ano anterior e já recebeu ao menos #{brl(
         ExpenseAnomalies::NEW_SUPPLIER_MIN, precision: 0
       )}."]
    end
  end

  # "01.11-3/01 (cultivo de arroz)"
  def cnae_label(cnae)
    return "não informada" if cnae.blank? || cnae[:code].blank?

    [cnae[:code], ("(#{cnae[:description].to_s.downcase})" if cnae[:description].present?)].compact.join(" ")
  end

  def compare_value(row, cell)
    value = cell[:value]
    return "—" if value.nil?

    case row.format
    when :currency then brl(value)
    when :percent  then percent(value)
    when :decimal  then number_with_precision(value, precision: 1, separator: ",")
    else value.to_s
    end
  end

  # ----- PANORAMA (/deputies/compare) -----

  # Cabeçalho ordenável da tabela do panorama, mantendo os filtros de estado e partido
  def deputy_panorama_sort_link(label, key, sort, direction)
    active = key == sort
    next_direction = if active
                       direction == :desc ? :asc : :desc
                     else
                       DeputyPanorama::SORTS[key][:default]
                     end
    arrow = { asc: "fa-arrow-up-short-wide", desc: "fa-arrow-down-wide-short" }[direction] if active
    query = request.query_parameters.except("page", "sort", "dir").merge(sort: key, dir: next_direction)
    link_to compare_deputies_path(query),
            class: "text-reset text-decoration-none" do
      safe_join([label, (tag.i(class: "fa-solid #{arrow} ms-1 text-gold", aria: { hidden: true }) if arrow)].compact)
    end
  end

  # Área do mapa de posicionamento dos deputados, em unidades do viewBox
  DEPUTY_POSITIONING = { width: 720, height: 430, left: 52, right: 16, top: 30, bottom: 48, r: 4.5 }.freeze

  # { x_ticks:, y_ticks:, points: [{ row:, cx:, cy: }] }
  # x = governismo (0 a 100%), y = alinhamento ao partido (do menor valor arredondado para baixo até 100%)
  def deputy_positioning_chart(rows)
    chart = DEPUTY_POSITIONING
    plot_w = chart[:width] - chart[:left] - chart[:right]
    plot_h = chart[:height] - chart[:top] - chart[:bottom]
    y_min = [((rows.map(&:alignment_pct).min.to_i - 2) / 10) * 10, 0].max

    x = ->(pct) { chart[:left] + (plot_w * pct / 100.0) }
    y = ->(pct) { chart[:top] + (plot_h * (100 - pct) / (100.0 - y_min)) }

    {
      chart: chart, plot_w: plot_w, plot_h: plot_h,
      x_ticks: (0..100).step(25).map { |pct| [pct, x.call(pct).round(1)] },
      y_ticks: (y_min..100).step(10).map { |pct| [pct, y.call(pct).round(1)] },
      government_x: x.call(DeputyPanorama::BLOCS[:government][:min]).round(1),
      center_x: x.call(DeputyPanorama::BLOCS[:center][:min]).round(1),
      points: rows.map do |row|
        { row: row, cx: x.call(row.governism_pct).round(1), cy: y.call(row.alignment_pct).round(1) }
      end
    }
  end
end
