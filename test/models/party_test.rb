require "test_helper"

class PartyTest < ActiveSupport::TestCase
  test "logo pela sigla, em qualquer caixa" do
    assert_equal "logo-pt.png", parties(:pt).logo_file
    assert_equal "logo-PDT.png", Party.new(label: "PDT", name: "Partido Democrático Trabalhista").logo_file
  end

  test "logo pelo nome sem acento quando a sigla não tem arquivo" do
    assert_equal "logo-uniaobrasil.png", Party.new(label: "UNIÃO", name: "União Brasil").logo_file
    assert_equal "logo-progressistas.png", Party.new(label: "PP", name: "Progressistas").logo_file
  end

  test "sem logo" do
    assert_nil Party.new(label: "XYZ", name: "Partido Inexistente").logo_file
  end
end
