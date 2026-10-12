require "test_helper"

class Suppliers::CnpjLookupTest < ActiveSupport::TestCase
  include HttpStub

  CNPJ = "56.031.006/0001-80"

  test "grava atividade principal, secundárias e situação cadastral" do
    body = {
      razao_social: "AC COMUNICACAO LTDA", cnae_fiscal: 7_311_400, cnae_fiscal_descricao: "Agências de publicidade",
      cnaes_secundarios: [{ codigo: 111_301, descricao: "Cultivo de arroz" }],
      descricao_situacao_cadastral: "ATIVA", data_situacao_cadastral: "2024-07-22"
    }
    supplier = with_http_response(Net::HTTPOK, "200", body.to_json) { Suppliers::CnpjLookup.call(CNPJ) }

    assert_equal "56031006000180", supplier.cnpj
    assert_equal ["7311400", "0111301"], supplier.cnae_codes # código que começa com 0 ganha o zero
    assert_equal ["ATIVA", Date.new(2024, 7, 22)], [supplier.registration_status, supplier.registration_status_date]
    assert_nil supplier.fetch_error
    assert_predicate supplier.fetched_at, :present?
    assert supplier.activity_in?(%w[011])
  end

  test "lista de secundárias vazia vem com código zero e é ignorada" do
    body = { cnae_fiscal: 4_731_800, cnaes_secundarios: [{ codigo: 0, descricao: "" }] }
    supplier = with_http_response(Net::HTTPOK, "200", body.to_json) { Suppliers::CnpjLookup.call(CNPJ) }
    assert_equal [], supplier.secondary_cnaes
  end

  test "CNPJ não encontrado grava o erro e só volta a ser consultado depois de 90 dias" do
    supplier = with_http_response(Net::HTTPNotFound, "404", { message: "CNPJ não encontrado" }.to_json) do
      Suppliers::CnpjLookup.call(CNPJ)
    end

    assert_equal "404: CNPJ não encontrado", supplier.fetch_error
    assert_not_includes Supplier.stale, supplier
  end

  test "limite de requisições grava o erro sem marcar como consultado" do
    lookup = Suppliers::CnpjLookup.new(CNPJ)
    with_http_response(Net::HTTPTooManyRequests, "429", "") { lookup.call }

    assert lookup.rate_limited?
    assert_match "429", lookup.supplier.fetch_error
    assert_includes Supplier.stale, lookup.supplier
  end

  test "instabilidade da API (5xx) não marca como consultado" do
    supplier = with_http_response(Net::HTTPGatewayTimeout, "504", "") { Suppliers::CnpjLookup.call(CNPJ) }
    assert_match "504", supplier.fetch_error
    assert_includes Supplier.stale, supplier
  end

  test "erro de rede não levanta exceção" do
    supplier = stub_http_start(->(*) { raise Net::OpenTimeout, "execution expired" }) { Suppliers::CnpjLookup.call(CNPJ) }
    assert_match "Net::OpenTimeout", supplier.fetch_error
    assert supplier.persisted?
  end

  test "conexão fechada no meio da resposta (EOFError) não levanta exceção" do
    supplier = stub_http_start(->(*, **) { raise EOFError, "end of file reached" }) { Suppliers::CnpjLookup.call(CNPJ) }
    assert_match "EOFError", supplier.fetch_error
    assert_includes Supplier.stale, supplier
  end

  test "erro repetido atualiza updated_at, para a rodada do job não tentar de novo" do
    supplier = Supplier.create!(cnpj: CNPJ, fetch_error: "504: Gateway Timeout", updated_at: 1.day.ago)
    with_http_response(Net::HTTPGatewayTimeout, "504", "") { Suppliers::CnpjLookup.call(CNPJ) }
    assert_operator supplier.reload.updated_at, :>, 1.minute.ago
  end

  test "CNPJ gravado por outra consulta ao mesmo tempo é atualizado em vez de duplicar" do
    lookup = Suppliers::CnpjLookup.new(CNPJ) # ainda não existe: vai criar
    Supplier.create!(cnpj: CNPJ, name: "Gravado pela outra consulta")

    body = { razao_social: "AC COMUNICACAO LTDA", cnae_fiscal: 7_311_400 }.to_json
    with_http_response(Net::HTTPOK, "200", body) { lookup.call }

    assert_equal 1, Supplier.where(cnpj: "56031006000180").count
    assert_equal "AC COMUNICACAO LTDA", Supplier.find_by(cnpj: "56031006000180").name
  end
end
