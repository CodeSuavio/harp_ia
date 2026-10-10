require "net/http"
require "json"

namespace :partidos do
  desc "Atualiza historico dos partidos a partir de db/seed_data/partidos_tse.rb"
  task tse: :environment do
    load Rails.root.join("db/seed_data/partidos_tse.rb")

    atualizados = 0
    extintos = 0
    ausentes = []

    PARTIDOS_TSE.each do |dados|
      party = Party.find_by("upper(label) = ?", dados[:label].upcase)

      if party
        party.update!(dados.slice(:number, :registered_on, :former_labels))
        atualizados += 1
      else
        ausentes << dados[:label]
      end
    end

    Party::MERGERS.each do |sigla, fusao|
      party = Party.find_by("upper(label) = ?", sigla.upcase)

      if party
        party.update!(succeeded_by: fusao[:succeeded_by], active: false)
        extintos += 1
      end
    end

    puts "partidos atualizados: #{atualizados}"
    puts "extintos atualizados: #{extintos}"
    puts "siglas sem partido no banco: #{ausentes.join(', ')}" if ausentes.any?
  end

  desc "Logo, lider e bancada na posse de cada partido (API da Camara)"
  task camara: :environment do
    api = "https://dadosabertos.camara.leg.br/api/v2"
    lista = camara_json("#{api}/partidos?itens=100&ordem=ASC&ordenarPor=sigla") || abort("nao consegui baixar a lista de partidos")
    ids = lista["dados"].to_h { |p| [p["sigla"].upcase, p["id"]] }

    atualizados = 0
    ausentes = []

    Party.find_each do |party|
      camara_id = party.camara_id || ids[party.label.upcase]
      dados = camara_id && camara_json("#{api}/partidos/#{camara_id}")&.dig("dados")
      next ausentes << party.label unless dados

      status = dados["status"] || {}
      lider = status["lider"] || {}
      party.update!(
        camara_id: camara_id,
        logo_url: (dados["urlLogo"] if camara_image?(dados["urlLogo"])),
        leader_json_id: lider["uri"].to_s[%r{/deputados/(\d+)}, 1],
        leader_name: lider["nome"].presence,
        seats_at_start: status["totalPosse"].presence&.to_i
      )
      atualizados += 1
    end

    puts "partidos atualizados: #{atualizados}"
    puts "sem dados na Camara: #{ausentes.join(', ')}" if ausentes.any?
  end

  desc "Historico de partidos de cada deputado (API da Camara)"
  task historico: :environment do
    api = "https://dadosabertos.camara.leg.br/api/v2"
    predecessors = PartyHistory.predecessors
    parties = Party.all.index_by { |party| party.label.upcase }

    importados = 0
    falhas = []

    Deputy.find_each do |deputy|
      dados = camara_json("#{api}/deputados/#{deputy.json_id}/historico")&.dig("dados")
      next falhas << deputy.name unless dados

      now = Time.current
      rows = PartyHistory.new(dados, predecessors: predecessors).entries.map do |entry|
        entry.to_h.merge(deputy_id: deputy.id, party_id: parties[entry.party_label]&.id, created_at: now, updated_at: now)
      end
      PartyAffiliation.transaction do
        deputy.party_affiliations.delete_all
        PartyAffiliation.insert_all(rows) if rows.any?
      end
      importados += 1
      sleep 0.2 # a API recusa muitas requisições seguidas
    end

    puts "historicos importados: #{importados}"
    puts "sem resposta da API: #{falhas.join(', ')}" if falhas.any?
  end

  desc "Orientacao de voto das liderancas em cada votacao (API da Camara). FORCE=1 rebaixa as ja importadas"
  task orientacoes: :environment do
    api = "https://dadosabertos.camara.leg.br/api/v2"
    partidos = Party.pluck(:label, :id).to_h { |label, id| [label.upcase, id] }
    # A Câmara só registra orientação de bancada nas votações do plenário
    polls = Poll.where(label_comission: "PLEN")
    polls = polls.where.not(id: PollOrientation.select(:poll_id)) unless ENV["FORCE"] == "1"

    total = polls.count
    importadas = 0
    puts "votacoes a consultar: #{total}"

    polls.order(date: :desc).find_each.with_index(1) do |poll, i|
      dados = camara_json("#{api}/votacoes/#{poll.json_id}/orientacoes")&.dig("dados")
      next unless dados

      linhas = dados.filter_map do |row|
        label = row["siglaPartidoBloco"].to_s.strip
        orientacao = row["orientacaoVoto"].to_s.strip
        next if label.blank? || orientacao.blank?

        { poll_id: poll.id, label: label, orientation: orientacao, party_id: partidos[label.upcase] }
      end

      PollOrientation.transaction do
        PollOrientation.where(poll_id: poll.id).delete_all
        PollOrientation.insert_all(linhas) if linhas.any?
      end
      importadas += linhas.size
      puts "#{i}/#{total}" if (i % 100).zero?
    end

    puts "orientacoes importadas: #{importadas}"
  end

  # Metade dos logos da API aponta para arquivos que não existem (a Câmara devolve uma página 404)
  def camara_image?(url)
    return false if url.blank?

    uri = URI(URI::DEFAULT_PARSER.escape(url))
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.head(uri.request_uri) }
    response.is_a?(Net::HTTPSuccess) && response["Content-Type"].to_s.start_with?("image/")
  rescue StandardError
    false
  end

  def camara_json(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri, "Accept" => "application/json")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
  rescue StandardError
    nil
  end
end
