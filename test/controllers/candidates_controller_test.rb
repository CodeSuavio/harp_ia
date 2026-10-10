require "test_helper"

class CandidatesControllerTest < ActionDispatch::IntegrationTest
  test "sigla do partido nos cartões leva à página do partido" do
    get candidates_path
    assert_select ".inspiration-card a.stretched-link[href=?]", candidate_path(candidates(:ana_2026))
    assert_select ".inspiration-card a.party-badge[href=?]", party_path(parties(:mdb)), text: "MDB"
  end

  test "candidato deputado mostra o histórico de partidos e a candidatura de 2026" do
    get candidate_path(candidates(:ana_2026))
    assert_select ".party-timeline-item", 3
    assert_select ".party-timeline-item.is-candidacy", text: /pelo mesmo partido/
  end
end
