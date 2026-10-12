require "test_helper"

# O link "Ver ranking completo" enviado pela Harpia deve abrir a página com
# a mesma ordem da resposta do chat, em todos os critérios e nas duas direções.
class HarpiaRankingLinksTest < ActionDispatch::IntegrationTest
  test "listagem de deputados mostra a mesma ordem do ranking da Harpia" do
    BillAuthor.create!(bill: bills(:ana_bill), deputy: deputies(:bruno))

    DeputyRankingTool::CRITERIA.each_key do |criterion|
      %w[desc asc].each do |order|
        result = DeputyRankingTool.new.call("criterion" => criterion, "order" => order)
        expected = result[:ranking].map { |row| row[:nome] }

        get result[:pagina]

        shown = css_select(".candidate-card h3").map { |h3| h3.text.strip }.first(expected.size)
        assert_equal expected, shown, "#{criterion} #{order}: #{result[:pagina]}"
      end
    end
  end

  test "link do ranking de deputados mantém filtros e ano" do
    result = DeputyRankingTool.new.call("criterion" => "expenses_total", "year" => 2024, "state" => "SP")

    get result[:pagina]

    assert_equal ["Ana Souza"], (css_select(".candidate-card h3").map { |h3| h3.text.strip }.first(1))
    assert_match "R$ 500 no ano", response.body
    assert_match "Gastos de 2024", response.body
  end

  test "comparação de partidos mostra a mesma ordem do ranking da Harpia" do
    PartyRankingTool::CRITERIA.each_key do |criterion|
      %w[desc asc].each do |order|
        result = PartyRankingTool.new.call("criterion" => criterion, "order" => order)
        expected = result[:ranking].map { |row| row[:sigla] }

        get result[:pagina]

        shown = css_select("#indicadores tbody th a.fw-bold, table tbody th a.fw-bold").map { |a| a.text.strip }.uniq
        assert_equal expected, shown.first(expected.size), "#{criterion} #{order}: #{result[:pagina]}"
      end
    end
  end
end
