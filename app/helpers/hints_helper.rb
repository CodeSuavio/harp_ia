module HintsHelper
  # Dicas localizadas por página (controller#action). Só para o que a página não explica sozinha.
  # mode "beacon": ponto discreto ao lado do recurso, abre o balão ao tocar (padrão).
  # mode "auto": o balão aparece sozinho na primeira vez que o recurso surge na tela.
  # contains: usa o elemento mais interno que tem esse texto.
  HINTS = {
    "polls#index" => [
      { id: "polls-governo", selector: "#governo", label: "filtro Governo venceu ou perdeu",
        text: "Governo venceu: o resultado foi o que o governo orientou. Governo perdeu: foi o contrário. Só entram votações em que o governo orientou Sim ou Não." },
      { id: "polls-nominais", selector: "label[for='all']", label: "votações sem voto nominal",
        text: "Nas votações simbólicas só o resultado fica registrado, sem o voto de cada deputado. Marque para incluí-las." },
      { id: "polls-texto-mantido", selector: ".badge", contains: "Texto mantido", label: "selo Texto mantido",
        text: "A votação era sobre mudar um trecho do projeto. A mudança não passou e o texto ficou como estava." }
    ],
    "polls#show" => [
      { id: "poll-selo", selector: ".badge[title*='orientou']", label: "selo de vitória ou derrota do governo",
        text: "Compara a orientação do governo com o resultado: venceu se coincidem, perdeu se não." },
      { id: "poll-artigo17", selector: "span", contains: "Artigo 17", label: "voto Artigo 17",
        text: "Artigo 17 marca quem presidia a sessão. Pelo Regimento da Câmara, o presidente só vota para desempatar." },
      { id: "poll-contra", selector: "h2", contains: "Votaram contra", label: "votos contra a maioria do partido",
        text: "Votaram diferente da maioria do próprio partido. O selo “contra a orientação” marca quem também votou contra o que o líder do partido orientou." }
    ],
    "deputies#show" => [
      { id: "dep-gastos-meses", selector: ".month-chart", mode: "auto", label: "gastos por mês",
        text: "Selecione uma barra para ver só as despesas daquele mês." }
    ]
  }.freeze

  def hints_page_key
    "#{controller_path}##{action_name}"
  end

  def page_hints
    HINTS.fetch(hints_page_key, []).map { |hint| { mode: "beacon" }.merge(hint) }
  end
end
