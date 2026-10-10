module ContextoHelper
  GOVERNOS = [
    [Date.new(2003, 1, 1),  Date.new(2010, 12, 31), "Lula", "PT"],
    [Date.new(2011, 1, 1),  Date.new(2016, 5, 11),  "Dilma", "PT"],
    [Date.new(2016, 5, 12), Date.new(2018, 12, 31), "Temer", "MDB"],
    [Date.new(2019, 1, 1),  Date.new(2022, 12, 31), "Bolsonaro", "PSL/PL"],
    [Date.new(2023, 1, 1),  Date.new(2027, 1, 4),   "Lula", "PT"]
  ].freeze

  # Liderança do Governo na Câmara (só o período coberto pelas votações carregadas)
  LIDERES_DO_GOVERNO = [
    [Date.new(2023, 1, 1),  Date.new(2026, 4, 12), "José Guimarães (PT-CE)"],
    [Date.new(2026, 4, 13), Date.new(2027, 1, 31), "Paulo Pimenta (PT-RS)"]
  ].freeze

  MESES = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

  def governo_em(date)
    return unless date

    day = date.to_date
    _, _, nome, partido = GOVERNOS.find { |inicio, fim, _, _| day.between?(inicio, fim) }
    "Governo #{nome} (#{partido})" if nome
  end

  def lider_do_governo_em(date)
    return unless date

    day = date.to_date
    LIDERES_DO_GOVERNO.find { |inicio, fim, _| day.between?(inicio, fim) }&.last
  end

  # Legislaturas começam em 1º de fevereiro; a 57ª começou em 2023
  def legislatura_numero(date)
    return unless date

    day = date.to_date
    inicio = day.month >= 2 ? day.year : day.year - 1
    57 + ((inicio - 2023) / 4.0).floor
  end

  def legislatura_em(date)
    numero = legislatura_numero(date)
    "#{numero}ª legislatura" if numero
  end

  def mes_ano(date)
    "#{MESES[date.month - 1]}/#{date.year}" if date
  end

  # :venceu / :perdeu / nil — compara a orientação do Governo com o resultado oficial
  def resultado_do_governo(poll, orientacao)
    return unless %w[Sim Não].include?(orientacao)
    return if poll.approval.nil? || poll.description.to_s.start_with?("Mantido o texto")

    (orientacao == "Sim") == poll.approval ? :venceu : :perdeu
  end

  def selo_do_governo(poll, orientacao)
    case resultado_do_governo(poll, orientacao)
    when :venceu then tag.span("Governo venceu", class: "badge text-bg-light border", title: "#{governo_em(poll.date)} orientou #{orientacao}")
    when :perdeu then tag.span("Governo perdeu", class: "badge text-bg-warning", title: "#{governo_em(poll.date)} orientou #{orientacao}")
    end
  end
end
