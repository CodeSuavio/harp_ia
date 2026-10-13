require "test_helper"

class HarpiaListToolsTest < ActiveSupport::TestCase
  # ----- PROJETOS DE LEI -----

  test "lista os projetos de um tema e de um partido, dos mais recentes para os mais antigos" do
    older = create_bill(1, party: :mdb, date: "2024-03-01", theme: :transparencia)
    create_bill(2, party: :pt, date: "2025-06-01", theme: :transparencia)
    create_bill(3, party: :mdb, date: "2025-07-01", theme: :saude)

    result = BillListTool.new.call("theme" => "transparencia", "party" => "mdb")

    assert_equal [bills(:ana_bill).id, older.id], (result[:projetos].map { |row| row[:id] })
    assert_equal 2, result[:total_de_projetos]
    assert_equal "sobre Transparência e administração pública, do MDB", result[:filtros]
    assert_equal ["Transparência e administração pública"], result[:projetos].first[:temas]
    assert_nil result[:recorte]
  end

  test "lista de projetos cortada continua pela Harpia e pela página de projetos com os mesmos filtros" do
    6.times { |index| create_bill(index + 1, party: :pt, date: "2025-0#{index + 1}-10", theme: :saude) }
    tool = BillListTool.new

    result = tool.call("theme" => "Saúde", "party" => "PT", "year" => 2025)

    assert_equal({ exibindo: 5, de: 6 }, result[:recorte])
    more, page, first = result[:acoes].map { |action| tool.actions.find(action[:id]) }
    assert_equal "Mostre as posições 6 a 6: projetos de lei sobre Saúde, do PT, de 2025, " \
                 "dos mais recentes para os mais antigos", more.value
    assert_equal "/bills?party=#{parties(:pt).id}&theme=#{themes(:saude).id}&year=2025", page.value
    assert_equal "Do que trata o PL 6/2025?", first.value
  end

  test "sem filtros traz os projetos mais recentes" do
    result = BillListTool.new.call({})

    assert_equal [bills(:ana_bill).id], (result[:projetos].map { |row| row[:id] })
    assert_nil result[:filtros]
  end

  test "lista de projetos recusa tema ou partido desconhecido" do
    assert_match "Use um destes: Transparência e administração pública, Saúde",
                 BillListTool.new.call("theme" => "astronomia")[:erro]
    assert BillListTool.new.call("party" => "XYZ")[:erro]
  end

  # ----- VOTAÇÕES -----

  test "lista as votações de um tema com o placar" do
    result = PollListTool.new.call("theme" => "Transparência")

    row = result[:votacoes].sole
    assert_equal polls(:first).id, row[:id]
    assert_equal({ "Sim" => 3 }, row[:placar])
    assert_nil row[:votos_da_bancada]
  end

  test "partido acrescenta os votos da bancada e a orientação da liderança, sem filtrar as votações" do
    tool = PollListTool.new
    result = tool.call("party" => "MDB", "limit" => 2)

    # As mesmas votações sem o partido, inclusive a 3ª, em que o MDB não votou
    assert_equal PollListTool.new.call("limit" => 20)[:votacoes].pluck(:id),
                 PollListTool.new.call("party" => "MDB", "limit" => 20)[:votacoes].pluck(:id)
    third, second = result[:votacoes]
    assert_equal "a bancada não votou", third[:votos_da_bancada]
    assert_equal({ "Sim" => 1, "Não" => 2 }, second[:votos_da_bancada])
    assert_equal "Sim", second[:orientacao_da_lideranca]
    assert_equal "com o voto do MDB", result[:filtros]
    assert result[:observacao]

    # Lista completa na página de votações e a aba Votações do partido como página relacionada
    links = tool.actions.all.select { |action| action.type == "link" }.to_h { |action| [action.label, action.value] }
    assert_equal "/polls", links["Ver lista completa"]
    assert_equal "/parties/#{parties(:mdb).id}?tab=votes", links["Ver votações do MDB"]
  end

  test "orientação do partido que orienta pela federação" do
    result = PollListTool.new.call("party" => "PT")

    assert_equal "Não", result[:votacoes].find { |row| row[:id] == polls(:third).id }[:orientacao_da_lideranca]
  end

  test "lista de votações cortada continua pela página de votações com os mesmos filtros" do
    tool = PollListTool.new
    result = tool.call("result" => "approved", "limit" => 1)

    assert_equal [polls(:first).id], (result[:votacoes].map { |row| row[:id] })
    assert_nil result[:recorte] # só a 1ª foi aprovada

    result = tool.call("limit" => 1)
    assert_equal({ exibindo: 1, de: 3 }, result[:recorte])
    page = result[:acoes].map { |action| tool.actions.find(action[:id]) }.find { |a| a.label == "Ver lista completa" }
    assert_equal "/polls", page.value
  end

  test "votações em que o Governo perdeu, com a orientação do Governo e a página com o mesmo filtro" do
    tool = PollListTool.new
    result = tool.call("government" => "lost")

    # Governo orientou Sim nas duas primeiras: venceu a 1ª (aprovada) e perdeu a 2ª (rejeitada)
    row = result[:votacoes].sole
    assert_equal polls(:second).id, row[:id]
    assert_equal "Sim", row[:orientacao_do_governo]
    assert_equal "em que o Governo perdeu", result[:filtros]
    assert_match "O Governo vence quando", result[:observacao]

    assert_equal [polls(:first).id], (PollListTool.new.call("government" => "won")[:votacoes].map { |r| r[:id] })
    assert_equal "/polls?governo=perdeu", tool.send(:page_path)
  end

  private

  def create_bill(number, party:, date:, theme:)
    year = date.to_date.year
    bill = Bill.create!(bill_type: "PL", number: number, bill_number: "PL #{number}/#{year}", year: year,
                        submission_date: date, party: parties(party), summary: "Projeto #{number}")
    BillTheme.create!(bill: bill, theme: themes(theme))
    bill
  end
end
