module CampaignFinancesHelper
  RESULT_BADGES = {
    "ELEITO POR QP" => ["text-bg-success", "fa-circle-check", "Eleito"],
    "ELEITO POR MÉDIA" => ["text-bg-success", "fa-circle-check", "Eleito por média"],
    "ELEITO" => ["text-bg-success", "fa-circle-check", "Eleito"],
    "SUPLENTE" => ["bg-light text-navy border", "fa-user-clock", "Suplente"],
    "NÃO ELEITO" => ["bg-light text-muted border", "fa-circle-xmark", "Não eleito"]
  }.freeze

  def campaign_result_badge(result)
    css, icon, label = RESULT_BADGES.fetch(result.to_s, ["bg-light text-muted border", "fa-circle-question", "Sem votação"])
    tag.span(class: "badge rounded-pill fw-medium #{css}") do
      safe_join([tag.i(class: "fa-solid #{icon} me-1", aria: { hidden: true }), label])
    end
  end

  def vote_count(value)
    number_with_delimiter(value.to_i, delimiter: ".")
  end

  def percent_br(value, precision: 1)
    "#{number_with_precision(value, precision: precision, separator: ',', delimiter: '.')}%"
  end

  # "2,3× a mediana de SP" / "metade da mediana": custo por voto contra os concorrentes do estado
  def cost_vs_median(cost, median)
    return if cost.nil? || median.to_f.zero?

    ratio = cost / median
    if ratio >= 1.05
      "#{number_with_precision(ratio, precision: 1, separator: ',')}× a mediana"
    elsif ratio <= 0.95
      "#{percent_br((1 - ratio) * 100, precision: 0)} abaixo da mediana"
    else
      "na mediana"
    end
  end
end
