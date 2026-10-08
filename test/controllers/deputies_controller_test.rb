require "test_helper"

class DeputiesControllerTest < ActionDispatch::IntegrationTest
  test "lista deputados com indicadores" do
    get deputies_path
    assert_response :success
    assert_select "h3", text: "Ana Souza"
    assert_select "input[data-deputy-compare-target=checkbox]", 4
  end

  test "botão abaixo dos filtros ativa a comparação e avisa o limite" do
    get deputies_path
    assert_select "button[data-action='deputy-compare#toggleMode']", text: /Comparar deputados/
    assert_select "span", text: /Compare até 3 deputados/
  end

  test "link de comparação sai do turbo frame da listagem" do
    get deputies_path
    assert_select "turbo-frame#deputies_list a[data-deputy-compare-target=link][data-turbo-frame=_top]"
  end

  test "busca por sigla do partido" do
    get deputies_path(q: "pt")
    assert_select "h3", count: 1, text: "Davi Rocha"
  end

  test "filtra por estado" do
    get deputies_path(state: "RJ")
    assert_select "h3", count: 2
  end

  test "ordena por maior gasto" do
    get deputies_path(sort: "expenses")
    assert_equal ["Bruno Lima", "Ana Souza"], css_select("h3").map(&:text).first(2)
  end

  test "ordena por quantidade de projetos" do
    get deputies_path(sort: "bills")
    assert_equal "Ana Souza", css_select("h3").first.text
  end

  test "ignora ordenação inválida" do
    get deputies_path(sort: "drop table")
    assert_response :success
  end

  test "perfil exibe todas as abas" do
    deputy = deputies(:ana)
    DeputiesController::TABS.each_key do |tab|
      get deputy_path(deputy, tab: tab)
      assert_response :success, "aba #{tab}"
    end
  end

  test "aba de gastos mostra totais e filtra por mês" do
    get deputy_path(deputies(:ana), tab: "expenses")
    assert_match "R$ 1.000,00", response.body
    assert_match "Posto Central", response.body

    get deputy_path(deputies(:ana), tab: "expenses", month: 4)
    assert_select "tbody tr td", text: "Imobiliária X"
    assert_select "tbody tr td", text: "Posto Central", count: 1 # só na tabela de fornecedores
  end

  test "aba de votações mostra alinhamento" do
    get deputy_path(deputies(:ana), tab: "votes")
    assert_match "50%", response.body
    assert_match "Votou contra o partido", response.body
  end

  test "ignora redes sociais malformadas" do
    get deputy_path(deputies(:ana))
    assert_response :success
    assert_select "a[href='https://www.instagram.com/ana']"
  end

  test "perfil sem dados pessoais esconde blocos vazios" do
    get deputy_path(deputies(:bruno))
    assert_no_match "Gabinete", response.body
    assert_no_match "E-mail", response.body
  end

  test "aceita os nomes antigos das abas em links já compartilhados" do
    get deputy_path(deputies(:ana), tab: "gastos")
    assert_select "a.nav-link.active", text: "Gastos"
  end

  test "tela de gastos antiga redireciona para a aba" do
    get deputy_expenses_path(deputies(:ana))
    assert_redirected_to deputy_path(deputies(:ana), tab: "expenses")
  end

  test "compara deputados lado a lado" do
    get compare_deputies_path(ids: [deputies(:ana).id, deputies(:bruno).id])
    assert_response :success
    assert_match "Ana Souza", response.body
    assert_match "Bruno Lima", response.body
    assert_match "R$ 3.000,00", response.body
  end

  test "ordena por participação e por votos contra o partido" do
    get deputies_path(sort: "participation")
    assert_equal "Ana Souza", css_select("h3").first.text

    get deputies_path(sort: "against_party")
    assert_equal "Ana Souza", css_select("h3").first.text
  end

  test "filtra candidatos à reeleição e mostra o selo no card" do
    get deputies_path(reelection: "1")
    assert_select "h3", count: 1, text: "Ana Souza"
    assert_match "Candidato à reeleição", response.body
  end

  test "mostra o resumo do recorte filtrado" do
    get deputies_path(state: "SP")
    assert_match "R$ 1.750", response.body # média mensal de Ana (500) e Bruno (3000)
    assert_match "gasto médio mensal em 2025", response.body
  end

  test "aba de gastos mostra cota, ranking, variação anual e alerta de fornecedor" do
    get deputy_path(deputies(:ana), tab: "expenses")
    assert_match "Uso da cota", response.body
    assert_match "2º <small", response.body
    assert_match "+100%", response.body
    assert_match "70% dos gastos de 2025", response.body
  end

  test "mascara CPF de fornecedor pessoa física" do
    get deputy_path(deputies(:ana), tab: "expenses")
    assert_match "***.456.789-**", response.body
    assert_no_match "123.456.789-01", response.body
    assert_match "00.000.000/0001-00", response.body # CNPJ continua visível
  end

  test "aba de votações filtra votos contra o partido e por tema" do
    get deputy_path(deputies(:ana), tab: "votes", vote: "against_party")
    assert_select "tbody tr", count: 1
    assert_match "Votação do requerimento B", response.body

    get deputy_path(deputies(:ana), tab: "votes", theme: "transparency")
    assert_select "tbody tr", count: 1
    assert_match "Votação do requerimento A", response.body
  end

  test "aba de projetos mostra temas e compara com a média da Câmara" do
    get deputy_path(deputies(:ana), tab: "bills")
    assert_match "Transparência e administração pública (1)", response.body
    assert_match "acima da média da Câmara", response.body

    get deputy_path(deputies(:bruno), tab: "bills", theme: "transparency")
    assert_match "Nenhum projeto de lei encontrado", response.body
  end

  test "aba de promessas cruza propostas com a atuação" do
    get deputy_path(deputies(:ana), tab: "promises")
    assert_response :success
    assert_match "Mais transparência nos gastos públicos", response.body
    assert_match "Programa do partido", response.body
    assert_match "pouco conclusivo", response.body
    assert_select "td span.fw-bold", text: "1/2"
  end

  test "aba de promessas sem propostas mostra só a atuação" do
    get deputy_path(deputies(:davi), tab: "promises")
    assert_response :success
    assert_match "Nenhuma proposta cadastrada", response.body
  end

  test "comparação destaca melhor e pior e mostra divergência" do
    get compare_deputies_path(ids: [deputies(:ana).id, deputies(:bruno).id])
    assert_select "td.compare-best", minimum: 1
    assert_select "td.compare-worst", minimum: 1
    assert_match "Coerência com as propostas", response.body
    assert_match "votaram diferente em <strong>1</strong> de 2", response.body
  end

  test "comparação pede ao menos dois deputados" do
    get compare_deputies_path(ids: [deputies(:ana).id])
    assert_match "Selecione de 2", response.body
  end
end
