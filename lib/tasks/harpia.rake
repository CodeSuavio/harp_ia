namespace :harpia do
  desc "Cria/atualiza o catálogo de temas e reclassifica projetos de lei e votações"
  task themes: :environment do
    ThemeClassifier.sync_catalog!
    result = ThemeClassifier.new.classify_all!
    puts "#{Theme.count} temas · #{result[:bills]} vínculos de projetos · #{result[:polls]} vínculos de votações"
  end

  desc "Importa propostas de um arquivo JSON (ver ProposalImporter). Uso: bin/rails harpia:proposals[caminho.json]"
  task :proposals, [:path] => :environment do |_, args|
    abort "Informe o arquivo: bin/rails 'harpia:proposals[db/data/propostas.json]'" if args[:path].blank?

    result = ProposalImporter.new(JSON.parse(File.read(args[:path]))).call
    puts "#{result[:created]} propostas importadas"
    result[:errors].each { |error| puts "  ! #{error}" }
  end
end
