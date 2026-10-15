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

  test "o panorama de deputados lista as seções reais, com os números em deputy_panorama" do
    text = PageGuide.find("deputies#compare").text

    DeputyPanorama::SECTIONS.each_value { |section| assert_includes text, section[:title] }
    assert_includes text, DeputyPanorama::SECTIONS["positioning"][:reading]
    assert_includes text, "deputy_panorama"
    assert_not_includes text, "party_comparison"
  end

  test "toda seção do panorama tem os dados em deputy_panorama" do
    assert_equal DeputyPanorama::SECTIONS.keys, DeputyPanoramaTool::SECTIONS
  end

  test "página com gráficos ainda sem ferramenta avisa que os números estão na página" do
    guide = PageGuide.new("exemplo#show", { name: "exemplo", sections: DeputyPanorama::SECTIONS, data: nil })

    assert_includes guide.text, PageGuide::NO_DATA
  end

  test "o resumo traz só os títulos e os tipos de gráfico" do
    summary = PageGuide.find("deputies#compare").summary

    assert_includes summary, DeputyPanorama::SECTIONS["positioning"][:chart]
    assert_not_includes summary, DeputyPanorama::SECTIONS["positioning"][:reading]
  end

  test "só as páginas com ferramenta de dados são conhecidas em qualquer pergunta" do
    assert_equal %w[parties#compare deputies#compare], PageGuide.with_data.map(&:key)
    assert_nil PageGuide.find("pages#home")
  end

  test "aponta as seções presentes em mais de uma página pelo id, com os títulos de cada uma" do
    shared = PageGuide.shared_sections([PageGuide.find("deputies#compare"), PageGuide.find("parties#compare")])
    blocs = shared.find { |section| section[:titles].include?("A Câmara em blocos") }

    assert_equal ["A Câmara em blocos", "A Câmara em blocos, deputado a deputado"], blocs[:titles]
    assert_equal ["comparação de partidos", "panorama de deputados"], blocs[:pages]
    assert_equal 4, shared.size
    assert(shared.none? { |section| section[:titles].include?("Quem vota com quem") })
    assert_empty PageGuide.shared_sections([PageGuide.find("parties#compare"), PageGuide.find("parties#compare")])
  end
end
