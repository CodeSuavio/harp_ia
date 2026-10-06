module PainelHelper
  VOTE_COLORS = {
    "Sim" => "bg-success",
    "Não" => "bg-danger",
    "Abstenção" => "bg-secondary",
    "Obstrução" => "bg-warning",
    "Artigo 17" => "bg-info"
  }.freeze

  def bar_percent(value, max)
    return 0 unless max.to_f.positive?

    [(value.to_f / max.to_f * 100).round(1), 0].max
  end

  def vote_color(label)
    VOTE_COLORS.fetch(label, "bg-secondary")
  end
end
