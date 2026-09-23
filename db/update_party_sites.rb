SITES = {
  "MDB" => "www.mdb.org.br",
  "PDT" => "www.pdt.org.br",
  "PT" => "www.pt.org.br",
  "PCdoB" => "www.pcdob.org.br",
  "PSB" => "www.psb40.org.br",
  "PSDB" => "www.psdb.org.br",
  "AGIR" => "agir36.com.br",
  "MOBILIZA" => "www.mobiliza.org.br",
  "CIDADANIA" => "rede23.org",
  "PV" => "www.pv.org.br",
  "AVANTE" => "www.avante70.org.br",
  "PP" => "www.pp.org.br",
  "PSTU" => "www.pstu.org.br",
  "PCB" => "www.pcb.org.br",
  "PRTB" => "www.prtb.org.br",
  "DC" => "www.democraciacrista.org.br",
  "PCO" => "www.pco.org.br",
  "PODE" => "www.podemos.org.br",
  "REPUBLICANOS" => "republicanos10.org.br",
  "PSOL" => "www.psol50.org.br",
  "PL" => "partidoliberal.org.br",
  "PSD" => "www.psd.org.br",
  "SOLIDARIEDADE" => "www.solidariedade.org.br",
  "NOVO" => "www.novo.org.br",
  "REDE" => "www.redesustentabilidade.org.br",
  "DEMOCRATA" => "democrata.org.br",
  "UNIÃO" => "www.uniaobrasil.org.br",
  "MISSÃO" => "missao.org.br",
  "PRD" => "prd25.org.br",
  "UP" => "unidadepopular.org.br"
}

updated = 0
missing = []

SITES.each do |label, host|
  party = Party.find_by(label: label)

  if party.nil?
    missing << label
    next
  end

  party.update!(url: "https://#{host}")
  updated += 1
end

puts "#{updated} partidos atualizados"
puts "siglas nao encontradas no banco: #{missing.join(', ')}" if missing.any?
