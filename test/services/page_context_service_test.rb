require "test_helper"

class PageContextServiceTest < ActiveSupport::TestCase
  test "descreve o perfil do deputado com a aba e o ano" do
    deputy = deputies(:ana)
    context = PageContextService.new("/deputies/#{deputy.id}?tab=expenses&year=2025").call

    assert_includes context, "Ana Souza"
    assert_includes context, "deputy_id #{deputy.id}"
    assert_includes context, "aba \"Gastos\""
    assert_includes context, "ano 2025"
  end

  test "descreve a página de uma votação" do
    poll = polls(:first)
    assert_includes PageContextService.new("/polls/#{poll.id}").call, "poll_id #{poll.id}"
  end

  test "ignora páginas sem dados, desconhecidas e caminhos externos" do
    assert_nil PageContextService.new("/chats").call
    assert_nil PageContextService.new("/nao-existe").call
    assert_nil PageContextService.new("//exemplo.com/deputies/1").call
    assert_nil PageContextService.new("https://exemplo.com").call
    assert_nil PageContextService.new(nil).call
  end
end

class PageContextServiceSortTest < ActiveSupport::TestCase
  test "informa a ordenação das páginas de ranking" do
    assert_equal "Comparação entre partidos, ordenada por \"Coesão\", do menor para o maior",
                 PageContextService.new("/parties/compare?sort=cohesion&dir=asc").call
    assert_equal "Lista de deputados, ordenada por \"Gasto mensal\"",
                 PageContextService.new("/deputies?sort=expenses").call
    assert_equal "Lista de deputados, ordenada por \"Participação nas votações\", do menor para o maior",
                 PageContextService.new("/deputies?sort=participation&dir=asc").call
  end

  test "identifica o panorama de deputados, com filtros e ordenação, e a comparação de deputados escolhidos" do
    assert_equal "Panorama de comparação entre os deputados",
                 PageContextService.new("/deputies/compare").call
    assert_equal "Panorama de comparação entre os deputados com os filtros state=SP, ordenada por \"Gasto mensal\"",
                 PageContextService.new("/deputies/compare?state=SP&sort=expenses").call

    ana = deputies(:ana)
    assert_includes PageContextService.new("/deputies/compare?ids[]=#{ana.id}").call,
                    "Comparação entre os deputados Ana Souza"
  end
end

class PageContextServiceGuideTest < ActiveSupport::TestCase
  test "reconhece as páginas com gráficos mapeados" do
    assert_equal "parties#compare", PageContextService.new("/parties/compare?sort=cohesion").guide.key
    assert_equal "deputies#compare", PageContextService.new("/deputies/compare?state=SP").guide.key
  end

  test "sem guia nas páginas sem gráficos mapeados e nas comparações de registros escolhidos" do
    assert_nil PageContextService.new("/parties/compare?ids[]=1&ids[]=2").guide
    assert_nil PageContextService.new("/deputies/compare?ids[]=1").guide
    assert_nil PageContextService.new("/deputies/#{deputies(:ana).id}").guide
    assert_nil PageContextService.new("/chats/1").guide
    assert_nil PageContextService.new(nil).guide
  end
end
