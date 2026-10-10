module IntroHelper
  # Tour curto de cada página: balões com seta apontando para onde clicar.
  # Aparece na primeira visita da sessão; passo cujo elemento não existe na página é pulado.
  PAGE_TOURS = {
    "deputies#index" => [
      ["h1", "Deputados em exercício, com gastos, projetos e participação nas votações."],
      ["#deputy-search", "Busque pelo nome do deputado ou pela sigla do partido."],
      ["[data-deputy-compare-target='modeButton']", "Ative e marque alguns deputados para compará-los lado a lado."]
    ],
    "deputies#show" => [
      ["h1", "Perfil do deputado. O ícone ⓘ ao lado de cada número explica como ele é calculado."],
      ["a[href*='tab=expenses']", "Gastos da cota parlamentar, com alerta para gastos fora do padrão."],
      ["a[href*='tab=votes']", "Como votou em cada votação e quando foi contra o próprio partido."]
    ],
    "deputies#compare" => [
      ["h1", "Deputados lado a lado: gastos, projetos e votações."]
    ],
    "candidates#index" => [
      ["h1", "Candidaturas a deputado federal em 2026."],
      ["input[name='q']", "Busque pelo nome de urna ou pela sigla do partido."],
      ["select[name='state']", "Filtre pelo seu estado para ver só quem concorre por ele."]
    ],
    "candidates#show" => [
      ["h1", "Ficha da candidatura. Se a pessoa já é deputada, aparecem os números do mandato."],
      ["a[href*='/bills?author=']", "Projetos que a pessoa assinou como autora ou coautora."]
    ],
    "parties#index" => [
      ["h1", "Bancadas de cada partido na Câmara."],
      ["[data-controller~='party-map']", "Clique num estado para ver como a bancada dele se divide entre os partidos."]
    ],
    "parties#show" => [
      ["h1", "Perfil do partido. As abas mostram bancada, votações, gastos, projetos e candidatos."],
      ["a[href*='tab=votes']", "Como o partido vota e se a bancada segue a orientação da liderança."]
    ],
    "parties#compare" => [
      ["h1", "Partidos lado a lado: bancada, alinhamento com o governo e coesão."],
      ["table thead", "Clique no nome de uma coluna para ordenar."]
    ],
    "polls#index" => [
      ["h1", "Votações nominais da Câmara em 2026."],
      ["select[name='governo']", "Veja só as votações em que a orientação do governo venceu ou perdeu."],
      [".inspiration-card", "Abra uma votação para ver como votou cada partido e cada estado."]
    ],
    "polls#show" => [
      ["h1", "O que foi votado, o resultado e a orientação do governo."],
      ["h2.h5", "Orientação da liderança de cada partido e se a bancada seguiu."],
      ["details", "Abra para ver como votou a bancada de cada estado."]
    ],
    "bills#index" => [
      ["h1", "Projetos e propostas apresentados em 2026 e os que foram a votação."],
      ["#bill-search", "Busque por assunto ou pelo número oficial, como PL 1822."],
      ["select[name='type']", "Filtre por tipo: projeto de lei (PL), lei complementar (PLP), emenda à Constituição (PEC) e outros."]
    ],
    "bills#show" => [
      ["p.fs-5", "Ficha do projeto: autores, quando foi apresentado e em que votações entrou."],
      ["a[href*='fichadetramitacao']", "Tramitação completa no site da Câmara."]
    ]
  }.freeze

  def page_tour
    key = "#{controller_path}##{action_name}"
    steps = PAGE_TOURS[key]
    [key, steps.map { |selector, text| { selector: selector, text: text } }] if steps
  end
end
