module ApplicationHelper
  # Converte o Markdown das respostas da IA em HTML e
  # sanitiza o conteúdo para exibição segura
  def render_markdown(text)
    # Cria uma variável html
    html = Commonmarker.to_html(text)
    # Sanitiza o html
    sanitize(html)
  end
end
