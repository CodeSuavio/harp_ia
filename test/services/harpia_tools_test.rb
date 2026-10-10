require "test_helper"

class HarpiaToolsTest < ActiveSupport::TestCase
  test "busca deputados pelo nome" do
    result = SearchPlatformTool.new.call("kind" => "deputado", "query" => "Ana")

    assert_equal [deputies(:ana).id], (result[:resultados].map { |row| row[:id] })
  end

  test "recusa tipo de busca desconhecido" do
    assert SearchPlatformTool.new.call("kind" => "usuario", "query" => "a")[:erro]
  end

  test "detalha o deputado com gastos e votações" do
    result = DeputyDetailsTool.new.call("deputy_id" => deputies(:ana).id, "year" => 2025)

    assert_equal "Ana Souza", result[:deputado][:nome]
    assert_equal 2025, result[:gastos][:ano]
    assert_equal 1000, result[:gastos][:total]
    assert result[:votacoes].key?(:alinhamento_com_partido)
    assert_not result[:deputado].key?(:cpf)
  end

  test "detalha partido, projeto e votação" do
    assert_equal parties(:pt).label, PartyDetailsTool.new.call("party_id" => parties(:pt).id)[:partido][:sigla]
    assert BillDetailsTool.new.call("bill_id" => bills(:ana_bill).id)[:projeto][:numero]
    assert PollDetailsTool.new.call("poll_id" => polls(:first).id)[:placar]
  end

  test "informa quando o registro não existe" do
    assert DeputyDetailsTool.new.call("deputy_id" => 0)[:erro]
  end
end
