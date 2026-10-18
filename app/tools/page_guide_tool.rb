# Guia das páginas da plataforma (PageGuide), para a Harpia reconhecer e
# explicar um gráfico, uma seção ou uma funcionalidade sem estar na página,
# inclusive quando o usuário a descreve só pela aparência ou pela finalidade
# ("o quadro azul", "as barrinhas de cada mês", "os pontos laranja").
#
# Sem page, o resumo de todas as páginas (título e formato de cada seção) e as
# seções que aparecem em mais de uma página, calculadas pelo PageGuide; com
# page, o mesmo guia que a Harpia recebe quando o usuário está na página.
class PageGuideTool < ApplicationTool
  RECORD_NOTE = "Os números desta página dependem do registro (o deputado, o partido, os escolhidos ou a " \
                "votação): sem ele, explique a seção pelo guia e, para os números, use o registro citado na " \
                "conversa ou pergunte qual.".freeze

  description <<~DESC
    Guia das páginas da plataforma: as seções de cada página (gráficos,
    tabelas, listas e funcionalidades), o que cada uma mostra e de onde vêm os
    números. Use para explicar um gráfico, uma seção ou como usar a
    plataforma quando a página atual não os tiver, inclusive se o usuário
    descrever só a aparência ou a finalidade. Sem page, devolve o resumo de
    todas as páginas, com o id de cada uma; com page, o guia dessa página.
  DESC

  param :page, desc: "Id da página, como no resumo (ex.: deputies#show/expenses). Sem page, o resumo de todas",
               required: false

  def execute(page: nil)
    return overview if page.blank?

    guide = PageGuide.find(page.to_s.strip)
    return { erro: "Página desconhecida. Consulte sem page para ver as páginas." } unless guide

    { pagina: guide.name, page: guide.key, guia: guide.text,
      observacao: (RECORD_NOTE if PageGuide::GUIDES.dig(guide.key, :record)) }.compact
  end

  private

  def overview
    guides = PageGuide.all
    {
      paginas: guides.map { |guide| { page: guide.key, nome: guide.name, secoes: guide.summary } },
      em_mais_de_uma_pagina: PageGuide.shared_sections(guides).map do |shared|
        "#{shared[:titles].join(' ou ')} (#{shared[:pages].join(', ')})"
      end,
      observacao: "As seções fora de em_mais_de_uma_pagina existem em uma página só: identificada pela descrição, " \
                  "não pergunte a página."
    }
  end
end
