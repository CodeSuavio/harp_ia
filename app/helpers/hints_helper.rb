module HintsHelper
  # Dicas localizadas por página (controller#action).
  # mode "beacon": ponto discreto ao lado do recurso, abre o balão ao tocar (padrão).
  # mode "auto": o balão aparece sozinho na primeira vez que o recurso surge na tela.
  # contains: quando o seletor pega mais de um elemento, usa o primeiro com esse texto.
  HINTS = {
    "polls#index" => [
      { id: "polls-governo", selector: "#governo", label: "filtro Governo venceu ou perdeu",
        text: "Venceu: o resultado seguiu a orientação do governo. Perdeu: o resultado foi contrário a ela." }
    ],
    "polls#show" => [
      { id: "poll-selo", selector: ".badge[title*='orientou']", label: "selo de vitória ou derrota do governo",
        text: "O governo orienta Sim ou Não. O selo compara essa orientação com o resultado da votação." },
      { id: "poll-estados", selector: "details > summary", label: "votos por estado",
        text: "Abra para ver como votaram os deputados de cada estado." },
      { id: "poll-contra", selector: "h2", contains: "Votaram contra", label: "votos contra a maioria do partido",
        text: "Deputados que votaram diferente da maioria do próprio partido. O selo marca quem contrariou a orientação da liderança." }
    ],
    "bills#index" => [
      { id: "bills-tipo", selector: "#type", label: "tipos de proposta",
        text: "PL: projeto de lei. PLP: lei complementar. PEC: emenda à Constituição. MPV: medida provisória. PDL: decreto legislativo. PRC: resolução da Câmara." }
    ],
    "deputies#index" => [
      { id: "dep-comparar", selector: ".btn-compare-mode", label: "comparar deputados",
        text: "Ative e marque até 3 deputados nos cartões para vê-los lado a lado." }
    ],
    "deputies#show" => [
      { id: "dep-gastos-meses", selector: ".month-chart", mode: "auto", label: "gastos por mês",
        text: "Selecione uma barra para ver só as despesas daquele mês." },
      { id: "dep-promessas", selector: "a[href*='tab=promises']", label: "aba Promessas e Atuação",
        text: "Compara, por tema, as promessas de campanha com a atuação no mandato." }
    ],
    "parties#index" => [
      { id: "parties-ver-brasil", selector: "[data-party-map-target='reset']", mode: "auto", label: "voltar ao total do país",
        text: "O painel mostra só o estado escolhido. Use Ver Brasil para voltar ao total do país." }
    ],
    "parties#compare" => [
      { id: "cmp-ordenar", selector: ".party-compare-table thead th:nth-child(2) a", label: "ordenar a tabela de indicadores",
        text: "Clique no nome de uma coluna para ordenar os partidos por aquele indicador." },
      { id: "cmp-matriz", selector: "h2", contains: "Quem vota com quem", label: "como ler Quem vota com quem",
        text: "Cada célula cruza dois partidos e mostra em quantas votações as duas bancadas votaram igual." }
    ]
  }.freeze

  def hints_page_key
    "#{controller_path}##{action_name}"
  end

  def page_hints
    HINTS.fetch(hints_page_key, []).map { |hint| { mode: "beacon" }.merge(hint) }
  end
end
