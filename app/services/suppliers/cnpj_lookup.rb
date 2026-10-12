module Suppliers
  # Consulta o cadastro de um CNPJ na BrasilAPI e grava em Supplier.
  # Erros da API (CNPJ inexistente, limite de requisições, rede) ficam em
  # fetch_error, sem levantar exceção, para o lote seguir.
  class CnpjLookup
    URL = "https://brasilapi.com.br/api/cnpj/v1/%s".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    # IOError cobre o EOFError de conexão fechada no meio da resposta
    NETWORK_ERRORS = [Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError,
                      Net::HTTPBadResponse, JSON::ParserError].freeze

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
      when Net::HTTPServerError
        # Instabilidade da API (502, 504): tenta de novo na próxima rodada
        save_error("#{response.code}: #{response.message}", fetched: false)
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
      persist!(
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

    # updated_at muda mesmo quando o erro se repete: o FetchJob usa para não
    # consultar de novo, na mesma rodada, um CNPJ que acabou de falhar
    def save_error(message, fetched: true)
      persist!(fetch_error: message, fetched_at: (Time.current if fetched), updated_at: Time.current)
    end

    # Duas consultas do mesmo CNPJ ao mesmo tempo (ex.: rake task com o job rodando):
    # a segunda grava por cima do registro que a primeira criou
    def persist!(attributes)
      supplier.update!(attributes)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      raise unless supplier.new_record? && Supplier.exists?(cnpj: supplier.cnpj)

      Rails.logger.info("Suppliers::CnpjLookup: #{supplier.cnpj} gravado por outra consulta (#{e.class})")
      @supplier = Supplier.find_by!(cnpj: supplier.cnpj)
      supplier.update!(attributes)
    end

    def error_message(response)
      JSON.parse(response.body.to_s)["message"].presence || response.message
    rescue JSON::ParserError
      response.message
    end
  end
end
