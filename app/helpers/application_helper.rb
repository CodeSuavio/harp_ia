module ApplicationHelper
  # Atributos permitidos pelo sanitize, mais o "start" das listas numeradas:
  # o "Ver mais" de um ranking continua a numeração (6., 7., ...)
  MARKDOWN_ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + ["start"]).freeze

  # Converte o Markdown das respostas da IA em HTML e
  # sanitiza o conteúdo para exibição segura
  def render_markdown(text)
    # Cria uma variável html
    html = Commonmarker.to_html(text)
    # Sanitiza o html
    sanitize(html, attributes: MARKDOWN_ATTRIBUTES)
  end
end
