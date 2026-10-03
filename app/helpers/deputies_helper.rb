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
