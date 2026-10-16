require "test_helper"

class PageGuideToolTest < ActiveSupport::TestCase
  setup { @tool = PageGuideTool.new }

  test "sem página: o resumo de todas as páginas e as seções em mais de uma" do
    result = @tool.call({})

    assert_equal PageGuide::GUIDES.keys, result[:paginas].pluck(:page)
    parties = result[:paginas].find { |page| page[:page] == "parties#compare" }
    assert_equal PageGuide.find("parties#compare").summary, parties[:secoes]
    assert(result[:em_mais_de_uma_pagina].any? { |line| line.start_with?("Mapa de posicionamento") })
    assert(result[:em_mais_de_uma_pagina].none? { |line| line.include?("Quem vota com quem") })
    assert_match(/existem em uma página só/, result[:observacao])
  end

  test "com página: o mesmo guia que a Harpia recebe na página" do
    result = @tool.call("page" => "parties#compare")

    assert_equal PageContextService.new("/parties/compare").guide.text, result[:guia]
    assert_nil result[:observacao]
  end

  test "páginas de um registro avisam que os números pedem o registro; a lista de partidos usa o mapa" do
    assert_match(/dependem do registro/, @tool.call("page" => "deputies#show/expenses")[:observacao])
    assert_equal "pages#home", @tool.call("page" => "parties#index")[:page]
    assert_match(/Página desconhecida/, @tool.call("page" => "x")[:erro])
  end

  test "funcionalidades e recursos de todas as páginas estão no guia" do
    summaries = @tool.call({})[:paginas].pluck(:secoes).join(" ")

    assert_includes summaries, "Comparar deputados"
    assert_includes summaries, "Escolher partidos"
    assert_includes summaries, "pontos laranja"
  end
end
