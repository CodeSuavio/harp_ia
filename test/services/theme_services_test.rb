require "test_helper"

class ThemeClassifierTest < ActiveSupport::TestCase
  setup do
    @classifier = ThemeClassifier.new
  end

  test "casa palavras inteiras e prefixos sem diferenciar acentos" do
    assert_equal [themes(:saude).id], @classifier.theme_ids_for("Atendimento hospitalar no SUS")
    assert_equal [themes(:transparencia).id], @classifier.theme_ids_for("Transparência nos Gastos Públicos")
  end

  test "palavra curta não casa como prefixo" do
    assert_empty @classifier.theme_ids_for("Suspensão de prazo")
  end

  test "reclassifica projetos e herda o tema do projeto na votação" do
    polls(:first).update!(bill: bills(:ana_bill))
    result = @classifier.classify_all!

    assert_equal 1, result[:bills]
    assert_equal [themes(:transparencia)], bills(:ana_bill).reload.themes.to_a
    assert_equal [themes(:transparencia)], polls(:first).reload.themes.to_a
    assert_empty polls(:second).reload.themes
  end

  test "sincroniza o catálogo sem duplicar temas existentes" do
    ThemeClassifier.sync_catalog!
    assert_equal ThemeClassifier::CATALOG.size, Theme.count
    assert_equal "Saúde", Theme.find_by(slug: "health").name
  end
end

class DeputyThemeProfileTest < ActiveSupport::TestCase
  setup do
    @profile = DeputyThemeProfile.new(deputies(:ana))
  end

  test "inclui as propostas do partido" do
    assert_equal [proposals(:mdb_transparencia)], @profile.proposals
    assert_empty DeputyThemeProfile.new(deputies(:davi)).proposals
  end

  test "mede a coerência dos votos com as propostas" do
    assert_equal({ coherent: 1, total: 2, pct: 50, conclusive: false }, @profile.coherence)
  end

  test "agrupa propostas, projetos e votações por tema" do
    row = @profile.rows.first
    assert_equal themes(:transparencia), row.theme
    assert_equal [1, 1, 1, 1], [row.bills_count, row.votes_count, row.coherent, row.contrary]
    assert_equal [["Transparência e administração pública", 1]], @profile.top_themes
  end
end

class ProposalImporterTest < ActiveSupport::TestCase
  test "importa propostas e liga votações" do
    rows = [{
      "source_kind" => "campanha", "deputy_json_id" => 1004, "theme" => "health",
      "title" => "Mais hospitais", "source_url" => "https://example.com",
      "polls" => [{ "json_id" => "p-3", "favorable_vote" => "Sim" }, { "json_id" => "nao-existe", "favorable_vote" => "Sim" }]
    }]

    result = ProposalImporter.new(rows).call
    proposal = Proposal.find_by(title: "Mais hospitais")

    assert_equal 1, result[:created]
    assert_match "nao-existe", result[:errors].first
    assert_equal deputies(:davi), proposal.deputy
    assert_equal parties(:pt), proposal.party
    assert_equal [polls(:third)], proposal.polls.to_a

    # Reimportar atualiza em vez de duplicar
    ProposalImporter.new(rows).call
    assert_equal 1, Proposal.where(title: "Mais hospitais").count
  end

  test "rejeita proposta sem deputado nem partido" do
    result = ProposalImporter.new([{ "source_kind" => "campanha", "theme" => "health", "title" => "Solta" }]).call
    assert_equal 0, result[:created]
    assert_match "deputado ou o partido", result[:errors].first
  end
end
