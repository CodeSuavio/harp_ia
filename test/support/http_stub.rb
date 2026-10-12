# Troca Net::HTTP.start durante o bloco, para testar integrações sem rede real.
#
#   with_http_response(Net::HTTPOK, "200", { a: 1 }.to_json) { ... }   # toda chamada recebe essa resposta
#   stub_http_start(->(*, **) { raise EOFError }) { ... }               # comportamento livre
module HttpStub
  def with_http_response(klass, code, body, &)
    response = fake_http_response(klass, code, body)
    stub_http_start(->(*, **) { response }, &)
  end

  def fake_http_response(klass, code, body)
    response = klass.new("1.1", code, "")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    response
  end

  def stub_http_start(implementation)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &implementation)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
