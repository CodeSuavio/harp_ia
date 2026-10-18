require "test_helper"

class CampaignFinanceImporterTest < ActiveSupport::TestCase
  test "grava votos e contas pelo sq_candidato e separa as fontes de receita" do
    candidate = candidates(:ana_2026)
    candidate.update!(electoral_id: "250000000001")
    rows = [
      {
        "sq_candidato" => "250000000001", "votos_nominais" => 1200, "votos_validos" => 1200,
        "situacao_turno" => "ELEITO POR MÉDIA", "despesas_contratadas" => 3000.5, "qt_despesas" => 4,
        "tipo_prestacao" => "Parcial", "principais_despesas" => [["Publicidade por materiais impressos", 2000.0]],
        "receitas_total" => 5000.0,
        "receitas_por_fonte" => { "FUNDO ESPECIAL" => 3000.0, "FUNDO PARTIDARIO" => 1000.0, "OUTROS RECURSOS" => 1000.0 },
        "receitas_por_origem" => { "Recursos próprios" => 600.0, "Recursos de pessoas físicas" => 400.0 }
      },
      { "sq_candidato" => "999", "votos_nominais" => 1 }
    ]

    assert_equal({ imported: 1, skipped: 1 }, CampaignFinanceImporter.new(rows).call)

    finance = candidate.reload.campaign_finance
    assert_equal 1200, finance.votes
    assert finance.elected?
    assert_equal 4000, finance.public_funds
    assert_equal 80.0, finance.public_share
    assert_equal 12.0, finance.own_share
    assert_in_delta 2.5, finance.cost_per_vote, 0.001
    assert_equal [{ "label" => "Publicidade por materiais impressos", "value" => 2000.0 }], finance.top_expenses
  end

  test "importar de novo substitui os dados anteriores" do
    candidates(:ana_2026).update!(electoral_id: "1")
    CampaignFinanceImporter.new([{ "sq_candidato" => "1", "votos_nominais" => 10 }]).call
    CampaignFinanceImporter.new([{ "sq_candidato" => "1", "votos_nominais" => 20 }]).call
    assert_equal [20], CampaignFinance.pluck(:votes)
  end
end
