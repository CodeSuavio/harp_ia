# Base das ferramentas que a Harpia usa para consultar o banco de dados.
#
# Cada ferramenta é somente leitura e devolve apenas dados públicos da
# plataforma (nunca dados de usuários ou de outros chats). O retorno é um
# Hash que o RubyLLM envia à IA como JSON.
#
# Além dos dados, cada ferramenta oferece os próximos passos possíveis no
# campo "acoes" (HarpiaActions): perguntas que a Harpia responde e páginas
# da plataforma ligadas ao que foi consultado.
class ApplicationTool < RubyLLM::Tool
  LIST_LIMIT = 10
  # Itens de um ranking por resposta: o que cabe no widget
  RANKING_LIMIT = 5

  attr_reader :actions

  # Todas as ferramentas de uma resposta compartilham o mesmo registro de ações
  def initialize(actions = HarpiaActions.new)
    @actions = actions
  end

  private

  # Helpers das views, para reaproveitar os mesmos textos e caminhos das páginas
  def helpers
    ApplicationController.helpers
  end

  # Caminhos das páginas (deputy_path etc.), para as ações de página
  def routes
    Rails.application.routes.url_helpers
  end

  def not_found(kind)
    { erro: "#{kind} não encontrado na base do Harp_IA." }
  end

  def money(value)
    value&.to_f&.round(2)
  end

  def party_label(record)
    record.party&.label
  end

  # Tema pelo nome, sem diferenciar maiúsculas e acentos, ou por parte dele
  # quando só um tema combina ("saude" → Saúde, "tributos" → Economia e tributos)
  def find_theme(name)
    term = normalize(name)
    return if term.blank?

    themes = Theme.all.to_a
    themes.find { |theme| normalize(theme.name) == term || theme.slug == term } ||
      themes.select { |theme| normalize(theme.name).include?(term) }.then { |found| found.first if found.one? }
  end

  def find_party(label)
    Party.find_by("label ILIKE ?", label.to_s.strip) if label.present?
  end

  # Erro quando o tema ou o partido informado não existe na base
  def lookup_error(theme, party)
    if theme.present? && !find_theme(theme)
      return { erro: "Tema não encontrado. Use um destes: #{Theme.pluck(:name).join(', ')}." }
    end

    not_found("Partido") if party.present? && !find_party(party)
  end

  def normalize(text)
    I18n.transliterate(text.to_s.strip).downcase
  end

  # ----- PRÓXIMOS PASSOS -----

  def question(label, text, required: false)
    actions.question(label, text, required: required)
  end

  def link(label, path, required: false)
    actions.link(label, path, required: required)
  end

  # ----- RANKINGS EM PARTES -----
  # Os rankings trazem RANKING_LIMIT itens por vez. Quando a lista foi
  # cortada, o campo "recorte" avisa a IA e as ações "Ver mais" (a próxima
  # parte, pela própria Harpia) e "Ver lista completa" (página existente,
  # quando houver) entram sempre abaixo da resposta.

  def ranking_limit(limit, max)
    limit.to_i.positive? ? [limit.to_i, max].min : RANKING_LIMIT
  end

  def recorte(shown, total)
    { exibindo: shown, de: total } if shown < total
  end

  # description: o ranking em palavras, para a pergunta "Ver mais" ser
  # entendida sozinha (ex.: "deputados por gasto mensal, do maior para o menor, em SP")
  def continuation(shown:, total:, max:, description:, page: nil)
    return if shown >= total

    upto = [shown + RANKING_LIMIT, max, total].min
    [
      (if upto > shown
         question("Ver mais", "Mostre as posições #{shown + 1} a #{upto}: #{description}", required: true)
       end),
      (link("Ver lista completa", page, required: true) if page)
    ].compact.presence
  end

  def order_label(direction)
    direction == :desc ? "do maior para o menor" : "do menor para o maior"
  end
end
