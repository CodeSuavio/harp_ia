require "test_helper"

class DeputiesHelperTest < ActionView::TestCase
  test "link da Câmara filtra deputado, ano, mês e legislatura" do
    deputy = deputies(:ana)
    assert_equal "https://www.camara.leg.br/transparencia/gastos-parlamentares?" \
                 "ano=2025&deputado=#{deputy.json_id}&legislatura=57&mes=MAR&por=deputado",
                 camara_expenses_url(deputy, 2025, 3)
    assert_match "legislatura=58", camara_expenses_url(deputy, 2027)
    assert_match "legislatura=56", camara_expenses_url(deputy, 2022)
    assert_no_match "mes=", camara_expenses_url(deputy, 2025)
  end
end
