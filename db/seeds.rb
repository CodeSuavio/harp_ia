require 'net/http'
require 'uri'
require 'json'
require 'open-uri'

$stdout.sync = true

# Sobe as fotos para o Cloudinary em paralelo: uma por vez levaria horas.
# photos: [[id, url_foto, nome], ...]. Foto que falhar (404, timeout) é
# registrada e pulada, sem derrubar o seed.
def upload_photos(model, photos, label)
  Rails.application.eager_load! # nada de autoload dentro das threads

  queue = Queue.new
  photos.each { |photo| queue << photo }
  attached = Concurrent::AtomicFixnum.new
  failed = Concurrent::Array.new

  # A thread principal já ocupa uma conexão do pool
  threads = Array.new([ActiveRecord::Base.connection_pool.size - 1, 1].max) do
    Thread.new do
      while (photo = (queue.pop(true) rescue nil))
        id, url, nome = photo
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            file = URI.parse(url).open(open_timeout: 10, read_timeout: 30)
            model.find(id).photo.attach(io: file, filename: "#{nome.split.first}.jpg", content_type: "image/jpeg")
          end
          count = attached.increment
          puts "#{count}/#{photos.size} fotos de #{label} enviadas" if (count % 250).zero?
        rescue StandardError => e
          failed << "#{nome} (#{url}): #{e.class} #{e.message}"
        end
      end
    end
  end
  ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.each(&:join) }

  puts "fotos de #{label}: #{attached.value} enviadas, #{failed.size} falharam"
  failed.each { |failure| puts "  falhou: #{failure}" }
end

# Propostas apontam para votações, partidos e deputados: saem antes
ProposalPoll.destroy_all
Proposal.destroy_all
BillTheme.destroy_all
PollTheme.destroy_all
Vote.destroy_all
Poll.destroy_all
Bill.destroy_all
Expense.destroy_all
Candidate.destroy_all
Deputy.destroy_all
Party.destroy_all

URL_PARTY = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/partidos.json"

url = URI.parse(URL_PARTY)

response = Net::HTTP.get(url)

data = JSON.parse(response)

data.each do |party|
  party = Party.new(
    label: party["sigla"],
    name: party["nome"],
    url: party["uri"]
  )
  party.save!
end

puts "importado #{Party.count} partidos"



URL_DEPUTY = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/deputados.json"

url = URI.parse(URL_DEPUTY)

response = Net::HTTP.get(url)

data = JSON.parse(response)

photos = []

data.each do |dep|
  party = Party.find_by(label: dep["sigla_partido"])
  if party
  deputy = Deputy.new(
    party: party,
    name: dep["nome"],
    cpf: dep["cpf"],
    json_id: dep["id"],
    education_level: dep["escolaridade"],
    city_of_birth: dep["municipio_nascimento"],
    email: dep["email"],
    date_of_birth: dep["data_nascimento"],
    state_label: dep["sigla_uf"]
    # photo_url
    # office_room: dep[""],
    # office_
  )
  deputy.save!
  photos << [deputy.id, dep["url_foto"], dep["nome"]] if dep["url_foto"].present?
  else
    puts "partido #{dep["sigla_partido"]} não encontrado"
  end
end
puts "importado #{Deputy.count} deputados"
upload_photos(Deputy, photos, "deputados")



URL_CANDIDATE = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/candidatos_2026.json"

url = URI.parse(URL_CANDIDATE)

response = Net::HTTP.get(url)

data = JSON.parse(response)

photos = []

data.each do |cara|
  party = Party.find_by(label: cara["sigla_partido"])
  if party
    candidate = Candidate.new(
      ballot_name: cara["nome_urna"],
      candidacy_status: cara["situacao_candidatura"],
      current_deputy_id: cara["deputado_id_atual"],
      education_level: cara["grau_instrucao"],
      electoral_id: cara["sq_candidato"].to_i,
      gender: cara["genero"],
      name: cara["nome"],
      number: cara["numero"].to_i,
      occupation: cara["ocupacao"],
      party: party,
      race_color: cara["raca_cor"],
      #running_for_reelection: cara["concorre_a_reeleicao"] <= campo inteiro veio vazio
      state_label: cara["sigla_uf"],
    )
    candidate.save!
    photos << [candidate.id, cara["url_foto"], cara["nome"]] if cara["url_foto"].present?
  else
    puts "partido #{cara["sigla_partido"]} não encontrado"
  end
end
puts "importado #{Candidate.count} candidatos"
upload_photos(Candidate, photos, "candidatos")


URL_PRPOSICAO = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/proposicoes.json"

deputies = Deputy.all.index_by(&:json_id)

url = URI.parse(URL_PRPOSICAO)

response = Net::HTTP.get(url)

data = JSON.parse(response)

data.uniq { |pl| pl["id"] }.each do |pl| # o json repete a proposição uma vez por coautor; fica o primeiro
  deputado = deputies[pl["deputado_id"].to_i]
  if deputado
    pl = Bill.new(
      bill_number: pl["id"].to_i,
      deputy: deputado,
      keywords: pl["keywords"],
      party_id: deputado.party_id,
      submission_date: pl["data_apresentacao"],
      summary: pl["ementa"],
      url: pl["url"],
      year: pl["ano"].to_i
    )
    pl.save!
  else
    puts "deputado #{pl["deputado_id"]} não encontrado"
  end
end
puts "importado #{Bill.count} proposições"



URL_EXPENSES = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/despesas.json"

url = URI.parse(URL_EXPENSES)

response = Net::HTTP.get(url)

data = JSON.parse(response)

data.each do |gasto|
  deputado = deputies[gasto["deputado_id"].to_i]
  if deputado
    gasto = Expense.new(
      deputy: deputado,
      document_amount: gasto["valor_documento"].to_f,
      document_date: gasto["data_documento"],
      document_url: gasto["url_documento"],
      expense_type: gasto["tipo_despesa"],
      month: gasto["mes"].to_i,
      net_amount: gasto["valor_liquido"].to_f,
      supplier: gasto["fornecedor"],
      supplier_cnpj_cpf: gasto["cnpj_cpf_fornecedor"],
      year: gasto["ano"].to_i
    )
    gasto.save!
  else
    puts "deputado #{gasto["deputado_id"]} não encontrado"
  end
end
puts "importado #{Expense.count} gastos"



URL_POLLS = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/votacoes.json"

url = URI.parse(URL_POLLS)

response = Net::HTTP.get(url)

data = JSON.parse(response)

data.uniq { |votacao| votacao["id"] }.each do |votacao|
  votacao = Poll.new(
    json_id: votacao["id"],
    approval: votacao["aprovacao"] == 1,
    bill: (Bill.find_by(bill_number: votacao["proposicao_id"].to_s) if votacao["proposicao_id"]),
    date: votacao["data"],
    description: votacao["descricao"],
    label_comission: votacao["sigla_orgao"]
  )
  votacao.save!
end
puts "importado #{Poll.count} votações"


URL_VOTES = "https://raw.githubusercontent.com/gabsgarcia/harpia-seed-data/refs/heads/main/db/seeds/votos.json"

polls = Poll.pluck(:json_id, :id).to_h

url = URI.parse(URL_VOTES)

response = Net::HTTP.get(url)

data = JSON.parse(response)

data.each do |voto|
  deputado = deputies[voto["deputado_id"].to_i]
  poll_id = polls[voto["votacao_id"]]
  if deputado && poll_id
    voto = Vote.new(
      deputy: deputado,
      poll_id: poll_id,
      vote: voto["voto"]
    )
    voto.save!
  else
    puts "deputado #{voto["deputado_id"]} ou votação #{voto["votacao_id"]} não encontrado"
  end
end
puts "importado #{Vote.count} votos"



# Temas: catálogo + classificação automática de projetos e votações
ThemeClassifier.sync_catalog!
result = ThemeClassifier.new.classify_all!
puts "classificados #{result[:bills]} vínculos de projetos e #{result[:polls]} de votações em #{Theme.count} temas"
