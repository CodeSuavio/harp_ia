require "test_helper"

class HarpiaActionsTest < ActiveSupport::TestCase
  LIST = "1. PL: 98\n2. PT: 64\n3. UNIÃO: 52\n4. PSD: 48\n5. PP: 46"

  setup do
    @actions = HarpiaActions.new
    @more = @actions.question("Ver mais", "Mostre as posições 6 a 10: deputados por gasto",
                              shown_if: [/(?<![\d.,])5\.(?!\d)/])
    @full = @actions.link("Ver lista completa", "/parties/compare?sort=seats#indicadores",
                          shown_if: [/PP/], list_page: "/parties/compare?sort=seats#indicadores")
    @profile = @actions.link("Ver perfil", "/deputies/1")
    @tab = @actions.link("Ver votações", "/deputies/1?tab=votes")
    @party = @actions.question("Sobre o PT", "Mostre os dados do partido PT")
  end

  test "a IA vê só o id, o tipo e o rótulo da ação" do
    assert_equal({ id: "a3", tipo: "página", rotulo: "Ver perfil" }, @profile)
    assert_equal "pergunta", @party[:tipo]
  end

  test "ids desconhecidos são descartados" do
    picked = @actions.pick([@party[:id], "a99", @profile[:id]], content: "Sem lista.")

    assert_equal ["Sobre o PT", "Ver perfil"], picked.pluck("label")
    assert_equal({ "type" => "link", "label" => "Ver perfil", "value" => "/deputies/1" }, picked.last)
  end

  test "a continuação entra sozinha, primeiro, quando a resposta mostrou a lista" do
    picked = @actions.pick([@profile[:id]], content: "Os 5 maiores:\n#{LIST}")

    assert_equal ["Ver mais", "Ver lista completa", "Ver perfil"], picked.pluck("label")
  end

  test "sem a lista na resposta, não há continuação, mesmo se a IA a escolher" do
    picked = @actions.pick([@more[:id], @full[:id], @profile[:id]], content: "O PL tem 98 deputados.")

    assert_equal ["Ver perfil"], picked.pluck("label")
    # Só o primeiro da lista (ex.: "qual deles gasta menos?" depois de um ranking de 10)
    assert_empty @actions.pick([], content: "1. Celso Sabino: R$ 0,03")
  end

  test "não continua a lista na página que já a mostra inteira, com qualquer ordenação" do
    picked = @actions.pick([], content: LIST, current_path: "/parties/compare?dir=desc&sort=governism")

    assert_equal ["Ver mais"], picked.pluck("label")
    # A comparação dos partidos escolhidos é outra página
    assert_equal ["Ver mais", "Ver lista completa"],
                 @actions.pick([], content: LIST, current_path: "/parties/compare?ids[]=1&ids[]=2").pluck("label")
  end

  test "a mesma ação registrada duas vezes tem o mesmo id" do
    assert_equal @profile, @actions.link("Ver perfil", "/deputies/1")
    assert_equal 5, @actions.all.size
  end

  test "não oferece link para a página em que o usuário já está" do
    picked = @actions.pick([@profile[:id], @tab[:id]], content: "", current_path: "/deputies/1?tab=expenses&year=2025")

    assert_equal ["Ver votações"], picked.pluck("label")
    assert_empty @actions.pick([@tab[:id]], content: "", current_path: "/deputies/1?tab=votes")
  end

  test "descobertas entram depois da continuação e antes das ações, até o máximo de botões" do
    picked = @actions.pick([@profile[:id], @tab[:id]], content: LIST, discoveries: ["Quais deles votam juntos?"])

    assert_equal ["Ver mais", "Ver lista completa", "Quais deles votam juntos?", "Ver perfil"], picked.pluck("label")
    assert_equal({ "type" => "question", "label" => "Quais deles votam juntos?",
                   "value" => "Quais deles votam juntos?" }, picked[2])
  end

  test "descobertas substituem as perguntas prontas das ferramentas, mas não as páginas" do
    picked = @actions.pick([@party[:id], @profile[:id]], content: "", discoveries: ["Como o PT vota?"])

    assert_equal ["Como o PT vota?", "Ver perfil"], picked.pluck("label")
    assert_equal ["Sobre o PT", "Ver perfil"], @actions.pick([@party[:id], @profile[:id]], content: "").pluck("label")
  end

  test "com opções de escolha, só elas e as ações escolhidas" do
    picked = @actions.pick([@party[:id]], content: LIST, discoveries: ["Outra pergunta"],
                                          clarifications: ["Por gastos", "Por projetos", "Por votações", "Por estado"])

    assert_equal ["Sobre o PT", "Por gastos", "Por projetos", "Por votações"], picked.pluck("label")
    assert_equal({ "type" => "question", "label" => "Por gastos", "value" => "Por gastos" }, picked[1])
  end
end
