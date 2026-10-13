require "test_helper"

class HarpiaActionsTest < ActiveSupport::TestCase
  setup do
    @actions = HarpiaActions.new
    @more = @actions.question("Ver mais", "Mostre as posições 6 a 10: partidos por cadeiras", required: true)
    @profile = @actions.link("Ver perfil", "/deputies/1")
    @tab = @actions.link("Ver votações", "/deputies/1?tab=votes")
    @party = @actions.question("Sobre o PT", "Mostre os dados do partido PT")
  end

  test "a IA vê só o id, o tipo e o rótulo da ação" do
    assert_equal({ id: "a2", tipo: "página", rotulo: "Ver perfil" }, @profile)
    assert_equal "pergunta", @party[:tipo]
  end

  test "as ações obrigatórias entram primeiro, e ids desconhecidos são descartados" do
    picked = @actions.pick([@party[:id], "a99", @profile[:id]])

    assert_equal ["Ver mais", "Sobre o PT", "Ver perfil"], picked.pluck("label")
    assert_equal({ "type" => "link", "label" => "Ver perfil", "value" => "/deputies/1" }, picked.last)
  end

  test "a mesma ação registrada duas vezes tem o mesmo id" do
    assert_equal @profile, @actions.link("Ver perfil", "/deputies/1")
    assert_equal 4, @actions.all.size
  end

  test "não oferece link para a página em que o usuário já está" do
    picked = @actions.pick([@profile[:id], @tab[:id]], current_path: "/deputies/1?tab=expenses&year=2025")

    assert_equal ["Ver mais", "Ver votações"], picked.pluck("label")
    assert_equal ["Ver mais"], @actions.pick([@tab[:id]], current_path: "/deputies/1?tab=votes").pluck("label")
  end

  test "opções de escolha entram como perguntas, no fim e até o máximo de botões" do
    picked = @actions.pick([@party[:id]], clarifications: ["Por gastos", "Por projetos", "Por votações"])

    assert_equal ["Ver mais", "Sobre o PT", "Por gastos", "Por projetos"], picked.pluck("label")
    assert_equal({ "type" => "question", "label" => "Por gastos", "value" => "Por gastos" }, picked[2])
  end
end
