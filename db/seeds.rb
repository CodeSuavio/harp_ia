require 'net/http'
require 'uri'
require 'json'

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
