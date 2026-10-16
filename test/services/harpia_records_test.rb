require "test_helper"

class HarpiaRecordsTest < ActiveSupport::TestCase
  setup do
    @records = HarpiaRecords.new
    @nikolas = Deputy.new(id: 1, name: "Nikolas Ferreira")
    @erika = Deputy.new(id: 2, name: "Erika Hilton")
    @palumbo = Deputy.new(id: 3, name: "Delegado Palumbo")
    @pt = Party.new(id: 10, label: "PT")
    @pl = Party.new(id: 11, label: "PL")
    [@nikolas, @erika, @palumbo].each { |deputy| @records.deputy(deputy) }
    [@pt, @pl].each { |party| @records.party(party) }
  end

  def names(text) = @records.presented_in(text).pluck("name")

  test "ficam só os registros consultados que a resposta apresentou, na ordem do texto" do
    assert_equal ["Erika Hilton", "Nikolas Ferreira"], names("Erika Hilton gasta menos que Nikolas Ferreira.")
    assert_equal({ "type" => "deputy", "id" => 2, "name" => "Erika Hilton" },
                 @records.presented_in("Erika Hilton").first)
    assert_empty @records.presented_in("Ninguém foi citado.")
  end

  test "reconhece o primeiro nome, sem os títulos, quando só um deputado consultado o tem" do
    assert_equal ["Erika Hilton", "Nikolas Ferreira", "Delegado Palumbo"],
                 names("A Erika vota diferente de Nikolas e de Palumbo.")

    @records.deputy(Deputy.new(id: 4, name: "Erika Kokay"))
    assert_equal [], names("A Erika vota diferente.")
  end

  test "não confunde parte de uma palavra nem maiúsculas" do
    assert_empty names("Os nikolas e as Erikas")
  end

  test "partido pela sigla, mas não a sigla que acompanha um deputado nem o tipo de um projeto" do
    assert_equal %w[PT PL], names("O PT e o PL votaram juntos em 29%.")
    assert_empty names("Nikolas Ferreira (PL-MG) e Erika Hilton (PT) apresentaram o PL 1234/2025.").grep(/\AP[LT]\z/)
    assert_equal %w[PL PT], names("PL-PT: 29%")
  end

  test "sigla escrita com minúsculas, mas não uma palavra comum" do
    @records.party(Party.new(id: 13, label: "PCDOB"))
    @records.party(Party.new(id: 14, label: "NOVO"))

    assert_equal %w[PCDOB NOVO], names("O PCdoB e o Novo")
    assert_empty names("um novo projeto do pcdob")
  end

  test "registra cada deputado ou partido uma vez e ignora registros vazios" do
    @records.deputy(@nikolas)
    @records.deputy(nil)
    @records.party(Party.new(id: 12, label: nil))

    assert_equal 5, @records.all.size
  end
end
