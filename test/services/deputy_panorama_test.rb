require "test_helper"

class DeputyPanoramaTest < ActiveSupport::TestCase
  setup do
    # As fixtures têm só 3 votações: com o mínimo padrão ninguém teria governismo
    @panorama = DeputyPanorama.new(min_government_polls: 1)
  end

  def row(name) = @panorama.rows.find { |r| r.deputy == deputies(name) }

  test "governismo e bloco de cada deputado" do
    assert_equal({ followed: 2, total: 2, pct: 100 }, row(:ana).governism)
    assert_equal :government, row(:ana).bloc
    assert_equal 50, row(:bruno).governism_pct
    assert_equal :center, row(:bruno).bloc
    assert_equal 0, row(:davi).governism_pct
    assert_equal :opposition, row(:davi).bloc
  end

  test "sem votações suficientes o deputado fica sem bloco" do
    panorama = DeputyPanorama.new
    assert(panorama.rows.all? { |r| r.governism.nil? && r.bloc == DeputyPanorama::NO_DATA })
    assert_equal 4, panorama.blocs[DeputyPanorama::NO_DATA][:count]
  end

  test "conta os blocos deputado a deputado" do
    counts = @panorama.blocs.transform_values { |bloc| bloc[:count] }
    assert_equal({ government: 1, center: 2, opposition: 1, no_data: 0 }, counts)
  end

  test "aponta quem vota num bloco diferente do partido" do
    # No MDB, Bruno e Carla são de centro; Ana é governista
    assert_equal [[row(:ana), :center]], @panorama.off_bloc
  end

  test "ordena, filtra e deixa quem não tem dado por último" do
    assert_equal(%w[Ana Carla Bruno Davi], @panorama.sorted_rows("governism", :desc).map { |r| r.name.split.first })
    assert_equal(%w[Carla Davi], @panorama.sorted_rows("name", :asc, state: "RJ").map { |r| r.name.split.first })
    assert_equal ["Davi Rocha"], @panorama.sorted_rows("name", :asc, party_id: parties(:pt).id).map(&:name)

    sorted = DeputyPanorama.new.sorted_rows("governism", :desc)
    assert_equal 4, sorted.size
  end

  test "destaques trazem blocos, votos contra o partido e gastos" do
    titles = @panorama.insights.map(&:second)
    assert_includes titles, "Quem decide as votações"
    assert_includes titles, "Fora do bloco do partido"
    assert_includes titles, "Gasto da cota parlamentar"
  end

  test "médias da Câmara e de um recorte" do
    chamber = @panorama.averages
    assert_in_delta 50.0, chamber[:governism_pct] # Ana 100, Bruno 50, Carla 50, Davi 0
    assert_equal DeputyMetrics.percentage(Deputy.running_for_reelection.count, 4), chamber[:reelection]

    rj = @panorama.averages(@panorama.sorted_rows("name", :asc, state: "RJ"))
    assert_in_delta 25.0, rj[:governism_pct] # Carla 50, Davi 0
  end
end
