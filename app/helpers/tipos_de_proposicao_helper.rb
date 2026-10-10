module TiposDeProposicaoHelper
  # Nomes oficiais (glossário do Congresso Nacional)
  TIPOS_DE_PROPOSICAO = {
    "PL" => "Projeto de lei",
    "PLP" => "Projeto de lei complementar",
    "PEC" => "Proposta de emenda à Constituição",
    "MPV" => "Medida provisória",
    "PDL" => "Projeto de decreto legislativo",
    "PRC" => "Projeto de resolução da Câmara"
  }.freeze

  # Aceita siglas ou pares [texto, valor] e devolve "PEC · Proposta de emenda à Constituição"
  def tipos_de_proposicao(opcoes)
    opcoes.map do |opcao|
      texto, valor = opcao.is_a?(Array) ? opcao : [opcao, opcao]
      nome = TIPOS_DE_PROPOSICAO[valor.to_s]
      nome ? ["#{valor} · #{nome}", valor] : [texto, valor]
    end
  end
end
