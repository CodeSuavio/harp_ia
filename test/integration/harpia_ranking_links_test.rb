require "test_helper"

# Páginas que a Harpia oferece como próximos passos (HarpiaActions):
# - "Ver lista completa" de um ranking cortado abre a página com a mesma
#   ordem, os mesmos filtros e o mesmo ano da resposta;
# - toda ação de página gerada pelas ferramentas abre uma página existente.
class HarpiaRankingLinksTest < ActionDispatch::IntegrationTest
  test "listagem de deputados mostra a mesma ordem do ranking da Harpia" do
    BillAuthor.create!(bill: bills(:ana_bill), deputy: deputies(:bruno))

    DeputyRankingTool::CRITERIA.each_key do |criterion|
      %w[desc asc].each do |order|
        expected = DeputyRankingTool.new.call("criterion" => criterion, "order" => order,
                                              "limit" => DeputyRankingTool::MAX_LIMIT)[:ranking].pluck(:nome)
        page = full_list_path(DeputyRankingTool, "criterion" => criterion, "order" => order)
        next unless page # ranking com um único deputado: nada foi cortado

        get page

        shown = css_select(".candidate-card h3").map { |h3| h3.text.strip }.first(expected.size)
        assert_equal expected, shown, "#{criterion} #{order}: #{page}"
      end
    end
  end

  test "lista completa do ranking de deputados mantém filtros e direção" do
    get full_list_path(DeputyRankingTool, "criterion" => "expenses_total", "state" => "SP", "order" => "asc")

    assert_equal ["Ana Souza", "Bruno Lima"], (css_select(".candidate-card h3").map { |h3| h3.text.strip })
    assert_match "R$ 1.000 no ano", response.body
  end

  test "lista completa do ranking de deputados mantém o ano dos gastos" do
    # Em 2024 só a Ana tem gastos (a lista não é cortada); o caminho é o mesmo de um ranking cortado
    get DeputyRankingTool.new.send(:page_path, "expenses_total", :desc, "SP", nil, 2024)

    assert_equal ["Ana Souza"], (css_select(".candidate-card h3").map { |h3| h3.text.strip }.first(1))
    assert_match "R$ 500 no ano", response.body
    assert_match "Gastos de 2024", response.body
  end

  test "comparação de partidos mostra a mesma ordem do ranking da Harpia" do
    PartyRankingTool::CRITERIA.each_key do |criterion|
      %w[desc asc].each do |order|
        expected = PartyRankingTool.new.call("criterion" => criterion, "order" => order)[:ranking].pluck(:sigla)
        page = full_list_path(PartyRankingTool, "criterion" => criterion, "order" => order)
        next unless page

        get page

        shown = css_select("#indicadores tbody th a.fw-bold, table tbody th a.fw-bold").map { |a| a.text.strip }.uniq
        assert_equal expected, shown.first(expected.size), "#{criterion} #{order}: #{page}"
      end
    end
  end

  test "página de alertas mostra a mesma ordem do ranking de alertas da Harpia" do
    ExpenseAlert.create!(deputy: deputies(:ana), year: 2025, kind: "atypical_note", severity: :high, value: 1_000)
    ExpenseAlert.create!(deputy: deputies(:bruno), year: 2025, kind: "atypical_note", severity: :medium, value: 50)
    ExpenseAlert.create!(deputy: deputies(:davi), year: 2025, kind: "atypical_note", severity: :high, value: 9_000)

    [{}, { "state" => "SP" }, { "severity" => "high" }, { "order" => "share" }].each do |args|
      expected = ExpenseAlertRankingTool.new.call(args.merge("limit" => 20))[:ranking].pluck(:nome)
      page = full_list_path(ExpenseAlertRankingTool, args)
      next unless page

      get page

      assert_equal expected, css_select(".card h2 a").map { |a| a.text.strip }, "#{args}: #{page}"
    end
  end

  test "rankings sem página de ranking oferecem só ver mais" do
    tools = [[DeputyStateRankingTool, {}], [DeputyStateRankingTool, { "criterion" => "expenses_total" }],
             [CandidateRankingTool, { "group_by" => "occupation" }]]

    tools.each do |tool_class, args|
      tool = tool_class.new
      tool.call(args.merge("limit" => 1))

      assert_empty link_actions(tool), "#{tool_class} #{args}"
    end
  end

  test "toda página oferecida pelas ferramentas existe" do
    candidate = deputies(:ana).candidates.first
    calls = {
      DeputyDetailsTool => { "deputy_id" => deputies(:ana).id },
      PartyDetailsTool => { "party_id" => parties(:pt).id },
      BillDetailsTool => { "bill_id" => bills(:ana_bill).id },
      PollDetailsTool => { "poll_id" => polls(:first).id },
      CandidateDetailsTool => { "candidate_id" => candidate.id },
      CandidateRankingTool => { "group_by" => "party", "state" => "SP", "gender" => "MASCULINO" },
      SearchPlatformTool => { "kind" => "votacao", "query" => "requerimento" }
    }

    paths = calls.flat_map do |tool_class, args|
      tool = tool_class.new
      tool.call(args)
      link_actions(tool).map(&:value)
    end
    paths << deputy_path(deputies(:ana), tab: "expenses", alerts: "1")

    assert_operator paths.size, :>, 10
    paths.uniq.each do |path|
      get path

      assert_response :success, path
    end
  end

  test "a página de um registro abre o registro consultado" do
    tool = DeputyDetailsTool.new
    tool.call("deputy_id" => deputies(:ana).id)

    get link_actions(tool).find { |action| action.label.start_with?("Ver perfil") }.value

    assert_includes response.body, deputies(:ana).name
  end

  private

  # "Ver lista completa" de um ranking cortado no primeiro item
  def full_list_path(tool_class, args)
    tool = tool_class.new
    tool.call(args.merge("limit" => 1))
    link_actions(tool).find { |action| action.label == "Ver lista completa" }&.value
  end

  def link_actions(tool)
    tool.actions.all.select { |action| action.type == "link" }
  end
end
