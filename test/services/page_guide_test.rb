require "test_helper"

class PageGuideTest < ActiveSupport::TestCase
  test "lista as seções da comparação de partidos, na ordem da página, com a ferramenta de cada uma" do
    text = PageGuide.find("parties#compare").text
    titles = PartyComparison::SECTIONS.values.pluck(:title)

    in_page_order = titles.sort_by { |title| text.index(title) }
    assert_equal titles, in_page_order
    assert_includes text, PartyComparison::SECTIONS["positioning"][:reading]
    assert_includes text, "party_comparison"
    assert_includes text, "party_ranking"
  end

  test "toda seção com gráfico tem os dados em party_comparison; a tabela fica com party_ranking" do
    assert_equal ["indicators"], PartyComparison::SECTIONS.keys - PartyComparisonTool::SECTIONS
    assert_empty PartyComparisonTool::SECTIONS - PartyComparison::SECTIONS.keys
  end

  test "o panorama de deputados lista as seções reais, avisando que ainda não há números para elas" do
    text = PageGuide.find("deputies#compare").text

    DeputyPanorama::SECTIONS.each_value { |section| assert_includes text, section[:title] }
    assert_includes text, DeputyPanorama::SECTIONS["positioning"][:reading]
    assert_includes text, PageGuide::NO_DATA
    assert_not_includes text, "party_comparison"
  end

  test "o resumo traz só os títulos e os tipos de gráfico" do
    summary = PageGuide.find("deputies#compare").summary

    assert_includes summary, DeputyPanorama::SECTIONS["positioning"][:chart]
    assert_not_includes summary, DeputyPanorama::SECTIONS["positioning"][:reading]
  end

  test "só as páginas com ferramenta de dados são conhecidas em qualquer pergunta" do
    assert_equal ["parties#compare"], PageGuide.with_data.map(&:key)
    assert_nil PageGuide.find("pages#home")
  end

  test "aponta os títulos repetidos entre páginas, com o nome de cada uma" do
    shared = PageGuide.shared_titles([PageGuide.find("deputies#compare"), PageGuide.find("parties#compare")])

    assert_equal ["panorama de deputados", "comparação de partidos"], shared["Mapa de posicionamento"]
    assert_not_includes shared.keys, "Quem vota com quem"
    assert_empty PageGuide.shared_titles([PageGuide.find("parties#compare"), PageGuide.find("parties#compare")])
  end
end
