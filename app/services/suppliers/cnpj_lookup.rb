module Suppliers
  # Consulta o cadastro de um CNPJ na BrasilAPI e grava em Supplier.
  # Erros da API (CNPJ inexistente, limite de requisições, rede) ficam em
  # fetch_error, sem levantar exceção, para o lote seguir.
  class CnpjLookup
    URL = "https://brasilapi.com.br/api/cnpj/v1/%s".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    NETWORK_ERRORS = [Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse,
                      JSON::ParserError].freeze

    attr_reader :supplier

    def self.call(cnpj) = new(cnpj).call

    def initialize(cnpj)
      @supplier = Supplier.find_or_initialize_by(cnpj: Supplier.normalize_value_for(:cnpj, cnpj))
    end

    # Devolve o Supplier gravado; rate_limited? diz se a API pediu para esperar
    def call
      handle(request)
      supplier
    rescue *NETWORK_ERRORS => e
      save_error("#{e.class}: #{e.message}".truncate(250), fetched: false)
      supplier
    end

    def rate_limited? = @rate_limited.present?

    private

    def handle(response)
      case response
      when Net::HTTPSuccess then store(JSON.parse(response.body))
      when Net::HTTPTooManyRequests
        # Sem fetched_at: continua "stale" e entra na próxima rodada
        @rate_limited = true
        save_error("429: limite de requisições da API", fetched: false)
      else
        # 404 (não encontrado) e 400 (CNPJ inválido) só voltam a ser consultados depois de REFRESH_AFTER
        save_error("#{response.code}: #{error_message(response)}")
      end
    end

    def request
      uri = URI(format(URL, supplier.cnpj))
      options = { use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
      Net::HTTP.start(uri.host, uri.port, **options) do |http|
        http.get(uri.request_uri, "Accept" => "application/json", "User-Agent" => "Harpia")
      end
    end

    def store(data)
      supplier.update!(
        name: data["razao_social"],
        cnae_code: cnae(data["cnae_fiscal"]), cnae_description: data["cnae_fiscal_descricao"],
        secondary_cnaes: secondary_cnaes(data["cnaes_secundarios"]),
        registration_status: data["descricao_situacao_cadastral"],
        registration_status_date: data["data_situacao_cadastral"],
        fetched_at: Time.current, fetch_error: nil
      )
    end

    # Sem atividades secundárias, a API devolve [{ codigo: 0, descricao: "" }]
    def secondary_cnaes(rows)
      Array(rows).filter_map do |row|
        code = cnae(row["codigo"])
        { "code" => code, "description" => row["descricao"] } if code
      end
    end

    # 4731800 → "4731800"; códigos que começam com 0 (ex.: 0111301) vêm sem o zero
    def cnae(value)
      value.to_i.positive? ? value.to_i.to_s.rjust(7, "0") : nil
    end

    def save_error(message, fetched: true)
      supplier.fetch_error = message
      supplier.fetched_at = fetched ? Time.current : nil
      supplier.save!
    end

    def error_message(response)
      JSON.parse(response.body.to_s)["message"].presence || response.message
    rescue JSON::ParserError
      response.message
    end
  end
end
