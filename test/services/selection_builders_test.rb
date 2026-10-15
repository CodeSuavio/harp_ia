require "test_helper"

# A página (controller) e a Harpia (SelectionComparisonTool) montam a seleção
# pelo mesmo caminho: mesma ordem, mesmos registros, mesmo limite
class SelectionBuildersTest < ActiveSupport::TestCase
  test "partidos na ordem da escolha, sem repetidos, desconhecidos ou vazios" do
    selection = PartySelectionComparison.for(["", parties(:pt).id.to_s, "999999", parties(:mdb).id, parties(:pt).id])

    assert_equal %w[PT MDB], selection.parties.map(&:label)
  end

  test "deputados na ordem da escolha, até o limite" do
    ids = %i[davi ana bruno carla].map { |name| deputies(name).id }
    comparison = DeputyComparison.for(ids)

    assert_equal ids.first(DeputyComparison::LIMIT), comparison.deputies.map(&:id)
  end
end
