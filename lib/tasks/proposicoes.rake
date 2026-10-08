require "net/http"
require "json"

namespace :proposicoes do
  desc "Numero oficial, autores e projetos de cada votacao (harpia-seed-data e API da Camara)"
  task cruzar: :environment do
    fonte = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/proposicoes.json"
    api = "https://dadosabertos.camara.leg.br/api/v2"
    tipos = %w[PL PLP PEC PDL PRC MPV]

    get_json = lambda do |url|
      uri = URI(url)
      request = Net::HTTP::Get.new(uri, "Accept" => "application/json")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
      response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
    rescue StandardError
      nil
    end

    linhas = get_json.call(fonte) || abort("nao consegui baixar #{fonte}")
    deputados = Deputy.pluck(:json_id, :id).to_h
    bills = Bill.pluck(:bill_number, :id).to_h
    numerados = 0
    autorias = 0

    ActiveRecord::Base.transaction do
      linhas.group_by { |pl| pl["id"].to_s }.each do |camara_id, rows|
        bill_id = bills[camara_id]
        next unless bill_id

        pl = rows.first
        ano = pl["data_apresentacao"].to_s[0, 4].to_i
        Bill.where(id: bill_id).update_all(bill_type: pl["sigla_tipo"], number: pl["numero"].to_i, year: ano > 1900 ? ano : pl["ano"].to_i)
        numerados += 1

        rows.map { |row| deputados[row["deputado_id"].to_i] }.compact.uniq.each do |deputy_id|
          BillAuthor.find_or_create_by!(bill_id: bill_id, deputy_id: deputy_id)
          autorias += 1
        end
      end
    end
    puts "projetos com numero oficial: #{numerados}"
    puts "autorias gravadas: #{autorias}"

    importar = lambda do |camara_id|
      dados = get_json.call("#{api}/proposicoes/#{camara_id}")&.dig("dados")
      return nil unless dados && tipos.include?(dados["siglaTipo"])

      ano = dados["ano"].to_i
      ano = dados["dataApresentacao"].to_s[0, 4].to_i if ano < 1900
      bill = Bill.create!(
        bill_number: camara_id,
        bill_type: dados["siglaTipo"],
        number: dados["numero"].to_i,
        year: ano,
        summary: dados["ementa"],
        keywords: dados["keywords"],
        submission_date: dados["dataApresentacao"],
        url: "https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=#{camara_id}"
      )
      autores = get_json.call("#{api}/proposicoes/#{camara_id}/autores")&.dig("dados") || []
      json_ids = autores.filter_map { |autor| autor["uri"].to_s[%r{/deputados/(\d+)\z}, 1]&.to_i }
      Deputy.where(json_id: json_ids).pluck(:id).each { |deputy_id| BillAuthor.find_or_create_by!(bill: bill, deputy_id: deputy_id) }
      bill
    end

    importados = 0
    vinculos = 0
    sem_resposta = []
    Poll.where(id: Vote.select(:poll_id)).find_each do |poll|
      dados = get_json.call("#{api}/votacoes/#{poll.json_id}")&.dig("dados")
      if dados.nil?
        sem_resposta << poll.json_id
        next
      end

      Array(dados["proposicoesAfetadas"]).each do |prop|
        camara_id = prop["id"].to_s
        bill = Bill.find_by(bill_number: camara_id)
        unless bill
          bill = importar.call(camara_id)
          importados += 1 if bill
        end
        next unless bill

        PollBill.find_or_create_by!(poll: poll, bill: bill)
        vinculos += 1
      end
      sleep 0.2
    end

    puts "projetos votados importados: #{importados}"
    puts "vinculos votacao-projeto: #{vinculos}"
    puts "votacoes com projeto: #{PollBill.distinct.count(:poll_id)} de #{Poll.where(id: Vote.select(:poll_id)).count}"
    puts "sem resposta da API (rodar de novo resolve): #{sem_resposta.join(', ')}" if sem_resposta.any?
  end
end
