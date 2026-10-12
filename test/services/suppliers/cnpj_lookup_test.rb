require "test_helper"

class Suppliers::CnpjLookupTest < ActiveSupport::TestCase
  CNPJ = "56.031.006/0001-80"

  test "grava atividade principal, secundárias e situação cadastral" do
    body = {
      razao_social: "AC COMUNICACAO LTDA", cnae_fiscal: 7_311_400, cnae_fiscal_descricao: "Agências de publicidade",
      cnaes_secundarios: [{ codigo: 111_301, descricao: "Cultivo de arroz" }],
      descricao_situacao_cadastral: "ATIVA", data_situacao_cadastral: "2024-07-22"
    }
    supplier = with_response(Net::HTTPOK, "200", body.to_json) { Suppliers::CnpjLookup.call(CNPJ) }

    assert_equal "56031006000180", supplier.cnpj
    assert_equal ["7311400", "0111301"], supplier.cnae_codes # código que começa com 0 ganha o zero
    assert_equal ["ATIVA", Date.new(2024, 7, 22)], [supplier.registration_status, supplier.registration_status_date]
    assert_nil supplier.fetch_error
    assert_predicate supplier.fetched_at, :present?
    assert supplier.activity_in?(%w[011])
  end

  test "lista de secundárias vazia vem com código zero e é ignorada" do
    body = { cnae_fiscal: 4_731_800, cnaes_secundarios: [{ codigo: 0, descricao: "" }] }
    supplier = with_response(Net::HTTPOK, "200", body.to_json) { Suppliers::CnpjLookup.call(CNPJ) }
    assert_equal [], supplier.secondary_cnaes
  end

  test "CNPJ não encontrado grava o erro e só volta a ser consultado depois de 90 dias" do
    supplier = with_response(Net::HTTPNotFound, "404", { message: "CNPJ não encontrado" }.to_json) do
      Suppliers::CnpjLookup.call(CNPJ)
    end

    assert_equal "404: CNPJ não encontrado", supplier.fetch_error
    assert_not_includes Supplier.stale, supplier
  end

  test "limite de requisições grava o erro sem marcar como consultado" do
    lookup = Suppliers::CnpjLookup.new(CNPJ)
    with_response(Net::HTTPTooManyRequests, "429", "") { lookup.call }

    assert lookup.rate_limited?
    assert_match "429", lookup.supplier.fetch_error
    assert_includes Supplier.stale, lookup.supplier
  end

  test "instabilidade da API (5xx) não marca como consultado" do
    supplier = with_response(Net::HTTPGatewayTimeout, "504", "") { Suppliers::CnpjLookup.call(CNPJ) }
    assert_match "504", supplier.fetch_error
    assert_includes Supplier.stale, supplier
  end

  test "erro de rede não levanta exceção" do
    supplier = stub_http_start(->(*) { raise Net::OpenTimeout, "execution expired" }) { Suppliers::CnpjLookup.call(CNPJ) }
    assert_match "Net::OpenTimeout", supplier.fetch_error
    assert supplier.persisted?
  end

  private

  def with_response(klass, code, body, &)
    response = klass.new("1.1", code, "")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    stub_http_start(->(*, **) { response }, &)
  end

  # Troca Net::HTTP.start durante o bloco (sem rede real)
  def stub_http_start(implementation)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &implementation)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
