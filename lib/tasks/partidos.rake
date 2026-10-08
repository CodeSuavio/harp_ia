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

    PARTIDOS_EXTINTOS_TSE.each do |dados|
      party = Party.find_by("upper(label) = ?", dados[:label].upcase)

      if party
        party.update!(succeeded_by: dados[:succeeded_by], active: false)
        extintos += 1
      end
    end

    puts "partidos atualizados: #{atualizados}"
    puts "extintos atualizados: #{extintos}"
    puts "siglas sem partido no banco: #{ausentes.join(', ')}" if ausentes.any?
  end
end
