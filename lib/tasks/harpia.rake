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

  desc "Consulta na BrasilAPI o CNAE dos fornecedores (CNPJ) das despesas. Uso: bin/rails 'harpia:suppliers[100]'"
  task :suppliers, [:limit] => :environment do |_, args|
    pending = Suppliers::FetchJob.pending_cnpjs
    pending = pending.first(args[:limit].to_i) if args[:limit].present?
    puts "#{pending.size} CNPJs para consultar (~#{(pending.size * Suppliers::FetchJob::PAUSE / 60).ceil} min)"

    Suppliers::FetchJob.fetch(pending)
    errors = Supplier.where.not(fetch_error: nil).count
    puts "#{pending.size} consultados · #{Supplier.with_activity.count} com CNAE · #{errors} com erro"

    ExpenseAlerts::RefreshJob.refresh_all_now if pending.any?
    puts "#{ExpenseAlert.count} alertas de gastos recalculados" if pending.any?
  end

  desc "Recalcula os alertas de gastos gravados (ranking /alertas) de todos os anos"
  task expense_alerts: :environment do
    ExpenseAlerts::RefreshJob.refresh_all_now
    puts "#{ExpenseAlert.count} alertas de gastos"
  end
end
