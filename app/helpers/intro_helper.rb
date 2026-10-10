module IntroHelper
  # Explicação curta que aparece na primeira visita a cada página, uma vez por sessão
  PAGE_INTROS = {
    "deputies#index"   => "Deputados em exercício. Busque por nome ou partido, filtre por estado e use \"Comparar deputados\" para ver alguns lado a lado.",
    "deputies#show"    => "Perfil do deputado. As abas mostram gastos da cota parlamentar, projetos, votações e a candidatura em 2026. O ícone ⓘ explica como cada número é calculado.",
    "deputies#compare" => "Deputados lado a lado: gastos, projetos e votações.",
    "candidates#index" => "Candidaturas a deputado federal em 2026. Filtre por estado, partido e gênero. Para quem já é deputado, o cartão traz o gasto mensal e a participação nas votações.",
    "candidates#show"  => "Ficha da candidatura. Se a pessoa já é deputada, aparecem os números do mandato e o link para o perfil completo.",
    "parties#index"    => "Bancadas na Câmara por estado. Clique num estado no mapa para ver a divisão ou num partido para abrir o perfil.",
    "parties#show"     => "Perfil do partido. As abas mostram a bancada, como o partido vota, gastos, projetos e candidatos em 2026.",
    "parties#compare"  => "Partidos lado a lado: tamanho da bancada, alinhamento com o governo e coesão nas votações. Clique no cabeçalho de uma coluna para ordenar.",
    "polls#index"      => "Votações nominais da Câmara em 2026. Filtre por tema, resultado ou se o governo venceu. Cada cartão leva aos votos por partido e por estado.",
    "polls#show"       => "Resultado da votação, orientação do governo e dos partidos, como cada bancada votou, como votou cada estado e quem votou contra o próprio partido.",
    "bills#index"      => "Projetos e propostas apresentados em 2026 e os que foram a votação. Busque por assunto ou pelo número (ex.: PL 1822).",
    "bills#show"       => "Ficha do projeto: autores, quando foi apresentado e em que votações entrou. O link no fim leva à tramitação na Câmara."
  }.freeze

  def page_intro
    key = "#{controller_path}##{action_name}"
    text = PAGE_INTROS[key]
    [key, text] if text
  end
end
