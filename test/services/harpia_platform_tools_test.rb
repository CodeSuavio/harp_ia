require "test_helper"

# As seções das páginas de registro que a Harpia consulta (perfil do deputado,
# página do partido, mapa de partidos e votação) trazem os mesmos dados que
# as páginas, pelos mesmos serviços.
class HarpiaPlatformToolsTest < ActiveSupport::TestCase
  setup do
    @ana = deputies(:ana)
    @tool = DeputyDetailsTool.new
  end

  # ----- PERFIL DO DEPUTADO -----

  test "gastos por mês: os 12 meses, como as barras da aba Gastos" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "gastos_por_mes")
    monthly = DeputyExpenseBreakdown.new(@ana.expenses.where(year: 2025)).monthly

    assert_equal "Gastos por mês", result[:secao]
    assert_equal 2025, result[:ano]
    assert_equal 12, result[:meses].size
    assert_equal %w[Jan Fev Mar], result[:meses].first(3).pluck(:mes)
    assert_equal monthly[3].to_f.round(2), result[:meses][2][:valor]
    assert_equal 0.0, result[:meses][0][:valor]
    assert_equal ["Ver aba Gastos"], result[:acoes].pluck(:rotulo)
  end

  test "fornecedores: os mesmos da página, com o CPF parcialmente oculto" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "fornecedores")
    expected = DeputyExpenseBreakdown.new(@ana.expenses.where(year: 2025)).top_suppliers

    assert_equal(expected.map { |supplier, *| supplier }, result[:fornecedores].pluck(:fornecedor))
    assert_includes result[:fornecedores].pluck(:cnpj_cpf), "***.456.789-**"
  end

  test "despesas: as notas mais recentes e o total do ano" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "despesas")
    notes = DeputyExpenseBreakdown.new(@ana.expenses.where(year: 2025)).notes

    assert_equal notes.count, result[:total_de_notas]
    assert_equal notes.first.supplier, result[:mais_recentes].first[:fornecedor]
  end

  test "votações recentes: o voto, a maioria do partido e se votou com ele, como a aba Votações" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "votacoes_recentes")
    history = DeputyVoteHistory.new(@ana)
    first = history.votes.first

    assert_equal @ana.votes.count, result[:total_de_votos]
    assert_equal history.against_party_ids.size, result[:votos_contra_o_partido]
    assert_equal first.vote, result[:mais_recentes].first[:voto]
    assert_equal history.majorities([first.poll_id])[first.poll_id], result[:mais_recentes].first[:maioria_do_partido]
  end

  test "votações por tema: os temas da aba, do que tem mais votações para o que tem menos" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "votacoes_por_tema")
    expected = DeputyVoteHistory.new(@ana).themes.sort_by { |_, count| -count }

    assert_equal(expected.map { |theme, count| { tema: theme.name, votacoes: count } }, result[:temas])
  end

  test "histórico de partidos: os períodos e as trocas, como a linha do tempo da Visão geral" do
    result = @tool.call("deputy_id" => @ana.id, "section" => "historico_de_partidos")

    assert_equal 1, result[:trocas_de_partido]
    assert_equal %w[PT MDB], result[:periodos].pluck(:partido)
    assert_equal "Troca de partido", result[:periodos].last[:evento]
    assert_match(/Sem histórico/, @tool.call("deputy_id" => deputies(:bruno).id,
                                             "section" => "historico_de_partidos")[:aviso])
  end

  test "sem seção, o retorno continua o mesmo; seção desconhecida é recusada" do
    result = @tool.call("deputy_id" => @ana.id)

    assert result[:gastos]
    assert_nil result[:secao]
    assert_match(/Seção inválida/, @tool.call("deputy_id" => @ana.id, "section" => "x")[:erro])
    assert_includes DeputyDetailsTool.new.description, "gastos_por_mes (Gastos por mês)"
  end

  # ----- PARTIDO, MAPA E VOTAÇÃO -----

  test "partido: histórico e votações mais disputadas, como a página" do
    result = PartyDetailsTool.new.call("party_id" => parties(:mdb).id)

    assert result.key?(:historico)
    assert_kind_of Array, result.dig(:votacoes, :votacoes_mais_disputadas)
  end

  test "mapa de partidos: cadeiras de cada partido no estado, na ordem do mapa" do
    tool = PartyRankingTool.new
    result = tool.call("criterion" => "seats", "state" => "sp")
    in_state = PartySeats.new.in_state("SP")

    assert_equal "Cadeiras em SP", result[:criterio]
    assert_equal in_state.values.sum, result[:total_de_cadeiras_no_estado]
    assert_equal in_state.values.sort.reverse, result[:ranking].pluck(:valor)
    assert_match(/só o critério seats/, tool.call("criterion" => "governism", "state" => "SP")[:erro])
    assert_match(/Estado inválido/, tool.call("criterion" => "seats", "state" => "XX")[:erro])
  end

  test "votação: como votou cada estado, como a página" do
    poll = polls(:first)
    result = PollDetailsTool.new.call("poll_id" => poll.id)

    assert_equal(PollBreakdown.new(poll).by_state.map { |uf, votes| [uf, votes["Sim"], votes["Não"]] },
                 result[:por_estado].map { |row| [row[:uf], row[:sim], row[:nao]] })
  end

  # ----- SERVIÇOS DAS PÁGINAS -----

  test "o mapa e o ranking por estado contam as cadeiras da mesma forma" do
    seats = PartySeats.new

    assert_equal Deputy.count, seats.state_totals.values.sum
    assert_equal Deputy.where(state_label: "SP").count, seats.in_state("SP").values.sum
  end

  test "votos contra o partido: o filtro da aba é o mesmo do histórico" do
    history = DeputyVoteHistory.new(@ana)
    against = history.votes(filter: DeputyVoteHistory::AGAINST_PARTY)

    assert_equal history.against_party_ids.sort, against.map(&:poll_id).sort
    assert_equal DeputiesController::AGAINST_PARTY, DeputyVoteHistory::AGAINST_PARTY
  end
end
