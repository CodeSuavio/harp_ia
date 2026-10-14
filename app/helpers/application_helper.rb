module ApplicationHelper
  # Ícone de link externo (abre em nova aba), no fim do texto do link.
  # Usa a cor do próprio link (currentColor): dourado nos links de texto,
  # azul-marinho ou escuro nos botões. O aviso em texto é para leitores de tela.
  # Ícone de link para outra página do próprio site, no fim do texto: só em links que levam
  # a outro conteúdo (perfil, lista relacionada, partido). Botões de ação ou do fluxo
  # (Voltar, Continuar conversa, Entrar, Comparar a seleção, Ir para a listagem) ficam sem ele.
  # Mesma regra de cor e tamanho do external_link_icon (currentColor); css:
  # troca a cor quando o ícone precisa se destacar (ex.: "text-gold" nos selos).
  def internal_link_icon(css: nil)
    tag.i(class: ["fa-solid fa-link internal-link-icon", css].compact.join(" "), aria: { hidden: true })
  end

  def external_link_icon
    safe_join([
                tag.i(class: "fa-solid fa-arrow-up-right-from-square external-link-icon", aria: { hidden: true }),
                tag.span("(abre em nova aba)", class: "visually-hidden")
              ])
  end

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
