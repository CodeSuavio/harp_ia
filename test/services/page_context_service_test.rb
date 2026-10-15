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

  test "informa o partido filtrado pela sigla, e não pelo id da URL" do
    assert_equal "Lista de deputados com os filtros state=SP, party=MDB",
                 PageContextService.new("/deputies?state=SP&party=#{parties(:mdb).id}").call
    assert_equal "Lista de deputados com os filtros party=999999", PageContextService.new("/deputies?party=999999").call
  end

  test "identifica o panorama de deputados, com filtros e ordenação, e a comparação de deputados escolhidos" do
    assert_equal "Panorama de comparação entre os deputados",
                 PageContextService.new("/deputies/compare").call
    assert_equal "Panorama de comparação entre os deputados com os filtros state=SP, ordenada por \"Gasto mensal\"",
                 PageContextService.new("/deputies/compare?state=SP&sort=expenses").call

    assert_equal "Panorama de comparação entre os deputados com os filtros party=PT",
                 PageContextService.new("/deputies/compare?party=#{parties(:pt).id}").call

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

  test "comparações por seleção têm guia só com ao menos 2 escolhidos" do
    two = "ids[]=#{parties(:pt).id}&ids[]=#{parties(:mdb).id}"
    assert_equal "parties#compare_selected", PageContextService.new("/parties/compare?#{two}").guide.key
    assert_equal "deputies#compare_selected",
                 PageContextService.new("/deputies/compare?ids[]=1&ids[]=2").guide.key
    assert_nil PageContextService.new("/parties/compare?ids[]=#{parties(:pt).id}").guide
    assert_nil PageContextService.new("/deputies/compare?ids[]=1&ids[]=1").guide
  end

  test "descreve os escolhidos na ordem da escolha, em português" do
    ana, bruno, davi = %i[ana bruno davi].map { |name| deputies(name) }
    context = PageContextService.new("/deputies/compare?ids[]=#{davi.id}&ids[]=#{ana.id}&ids[]=#{bruno.id}").call

    assert_equal "Comparação entre os deputados #{davi.name} (deputy_id #{davi.id}), " \
                 "#{ana.name} (deputy_id #{ana.id}) e #{bruno.name} (deputy_id #{bruno.id})", context
    assert_equal "Comparação entre os partidos PT (party_id #{parties(:pt).id}) e MDB (party_id #{parties(:mdb).id})",
                 PageContextService.new("/parties/compare?ids[]=#{parties(:pt).id}&ids[]=#{parties(:mdb).id}").call
    assert_nil PageContextService.new("/parties/compare?ids[]=999999").call
  end

  test "sem guia nas páginas sem gráficos mapeados" do
    assert_nil PageContextService.new("/deputies/#{deputies(:ana).id}").guide
    assert_nil PageContextService.new("/chats/1").guide
    assert_nil PageContextService.new(nil).guide
  end
end
