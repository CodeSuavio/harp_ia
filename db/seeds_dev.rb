require "json"

DIR = Rails.root.join("db", "seed_data")

TSE_PARTIES = [
  { label: "MDB", name: "Movimento Democrático Brasileiro", number: 15, registered_on: "1981-06-30", url: "www.mdb.org.br", former_labels: "PMDB" },
  { label: "PDT", name: "Partido Democrático Trabalhista", number: 12, registered_on: "1981-11-10", url: "www.pdt.org.br" },
  { label: "PT", name: "Partido dos Trabalhadores", number: 13, registered_on: "1982-02-11", url: "www.pt.org.br" },
  { label: "PCdoB", name: "Partido Comunista do Brasil", number: 65, registered_on: "1988-06-23", url: "www.pcdob.org.br", former_labels: "PPL" },
  { label: "PSB", name: "Partido Socialista Brasileiro", number: 40, registered_on: "1988-07-01", url: "www.psb40.org.br" },
  { label: "PSDB", name: "Partido da Social Democracia Brasileira", number: 45, registered_on: "1989-08-24", url: "www.psdb.org.br" },
  { label: "AGIR", name: "Agir", number: 36, registered_on: "1990-02-22", url: "agir36.com.br", former_labels: "PTC PRN" },
  { label: "MOBILIZA", name: "Mobilização Nacional", number: 33, registered_on: "1990-10-25", url: "www.mobiliza.org.br", former_labels: "PMN" },
  { label: "CIDADANIA", name: "Cidadania", number: 23, registered_on: "1992-03-19", url: "rede23.org", former_labels: "PPS" },
  { label: "PV", name: "Partido Verde", number: 43, registered_on: "1993-09-30", url: "www.pv.org.br" },
  { label: "AVANTE", name: "Avante", number: 70, registered_on: "1994-10-11", url: "www.avante70.org.br", former_labels: "PTdoB" },
  { label: "PP", name: "Progressistas", number: 11, registered_on: "1995-11-16", url: "www.pp.org.br", former_labels: "PPB PPR" },
  { label: "PSTU", name: "Partido Socialista dos Trabalhadores Unificado", number: 16, registered_on: "1995-12-19", url: "www.pstu.org.br" },
  { label: "PCB", name: "Partido Comunista Brasileiro", number: 21, registered_on: "1996-05-09", url: "www.pcb.org.br" },
  { label: "PRTB", name: "Partido Renovador Trabalhista Brasileiro", number: 28, registered_on: "1997-02-18", url: "www.prtb.org.br" },
  { label: "DC", name: "Democracia Cristã", number: 27, registered_on: "1997-08-05", url: "www.democraciacrista.org.br", former_labels: "PSDC" },
  { label: "PCO", name: "Partido da Causa Operária", number: 29, registered_on: "1997-09-30", url: "www.pco.org.br" },
  { label: "PODE", name: "Podemos", number: 20, registered_on: "1997-10-02", url: "www.podemos.org.br", former_labels: "PTN PHS PSC" },
  { label: "REPUBLICANOS", name: "Republicanos", number: 10, registered_on: "2005-08-25", url: "republicanos10.org.br", former_labels: "PRB PMR" },
  { label: "PSOL", name: "Partido Socialismo e Liberdade", number: 50, registered_on: "2005-09-15", url: "www.psol50.org.br" },
  { label: "PL", name: "Partido Liberal", number: 22, registered_on: "2006-12-19", url: "partidoliberal.org.br", former_labels: "PR PRONA" },
  { label: "PSD", name: "Partido Social Democrático", number: 55, registered_on: "2011-09-27", url: "www.psd.org.br" },
  { label: "SOLIDARIEDADE", name: "Solidariedade", number: 77, registered_on: "2013-09-24", url: "www.solidariedade.org.br", former_labels: "SD PROS" },
  { label: "NOVO", name: "Partido Novo", number: 30, registered_on: "2015-09-15", url: "www.novo.org.br" },
  { label: "REDE", name: "Rede Sustentabilidade", number: 18, registered_on: "2015-09-22", url: "www.redesustentabilidade.org.br" },
  { label: "DEMOCRATA", name: "Democrata", number: 35, registered_on: "2015-09-29", url: "democrata.org.br", former_labels: "PMB" },
  { label: "UP", name: "Unidade Popular", number: 80, registered_on: "2019-12-10", url: "unidadepopular.org.br" },
  { label: "UNIÃO", name: "União Brasil", number: 44, registered_on: "2022-02-08", url: "www.uniaobrasil.org.br", former_labels: "PSL DEM PFL" },
  { label: "PRD", name: "Partido Renovação Democrática", number: 25, registered_on: "2023-11-09", url: "prd25.org.br", former_labels: "PTB PATRIOTA PEN" },
  { label: "MISSÃO", name: "Partido Missão", number: 14, registered_on: "2025-11-04", url: "missao.org.br" }
]

def load_json(file)
  JSON.parse(File.read(DIR.join(file)))
end

def blank_marker?(value)
  value.blank? || value.to_s.start_with?("#")
end

Candidate.destroy_all
Deputy.destroy_all
Party.destroy_all

camara_ids = load_json("partidos.json").to_h { |p| [p["sigla"].upcase, p["id"]] }

TSE_PARTIES.each do |p|
  Party.create!(
    label: p[:label],
    name: p[:name],
    number: p[:number],
    registered_on: p[:registered_on],
    former_labels: p[:former_labels],
    active: true,
    url: "https://#{p[:url]}",
    camara_id: camara_ids[p[:label].upcase]
  )
end

parties_by_camara_id = Party.where.not(camara_id: nil).pluck(:camara_id, :id).to_h
parties_by_label = Party.pluck(:label, :id).to_h { |label, id| [label.upcase, id] }

skipped_deputies = 0

load_json("deputados.json").each do |d|
  party_id = parties_by_camara_id[d["partido_id"]]
  cpf = d["cpf"].to_s.gsub(/\D/, "")

  if party_id.nil? || cpf.length != 11
    skipped_deputies += 1
    next
  end

  office = d["gabinete"] || {}

  Deputy.create!(
    party_id: party_id,
    name: d["nome"],
    cpf: cpf,
    state_label: d["sigla_uf"],
    photo_url: d["url_foto"],
    email: d["email"],
    status: d["situacao"],
    electoral_status: d["condicao_eleitoral"],
    date_of_birth: d["data_nascimento"],
    city_of_birth: d["municipio_nascimento"],
    state_of_birth: d["uf_nascimento"],
    education_level: d["escolaridade"],
    social_media: Array(d["redes_sociais"]).join(" "),
    office_building: office["predio"],
    office_room: office["sala"],
    office_phone: office["telefone"]
  )
end

missing_parties = Hash.new(0)
skipped_candidates = 0

load_json("candidatos_2026.json").each do |c|
  party_id = parties_by_label[c["sigla_partido"].to_s.upcase]

  if party_id.nil?
    missing_parties[c["sigla_partido"]] += 1
    skipped_candidates += 1
    next
  end

  Candidate.create!(
    party_id: party_id,
    electoral_id: c["sq_candidato"],
    name: c["nome"],
    ballot_name: c["nome_urna"],
    number: c["numero"],
    state_label: c["sigla_uf"],
    candidacy_status: blank_marker?(c["situacao_candidatura"]) ? nil : c["situacao_candidatura"],
    running_for_reelection: c["concorre_a_reeleicao"],
    education_level: blank_marker?(c["grau_instrucao"]) ? nil : c["grau_instrucao"],
    occupation: blank_marker?(c["ocupacao"]) ? nil : c["ocupacao"],
    gender: blank_marker?(c["genero"]) ? nil : c["genero"],
    race_color: blank_marker?(c["raca_cor"]) ? nil : c["raca_cor"],
    photo_file: c["arquivo_foto"]
  )
end

puts "#{Party.count} partidos, #{Deputy.count} deputados, #{Candidate.count} candidatos"
puts "deputados pulados: #{skipped_deputies}" if skipped_deputies.positive?
puts "candidatos pulados: #{skipped_candidates}"
puts "siglas ainda sem partido: #{missing_parties.sort_by { |_, v| -v }.first(20).to_h}" if missing_parties.any?
