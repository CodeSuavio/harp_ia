require "test_helper"

class PartiesHelperTest < ActionView::TestCase
  Row = Struct.new(:label, :seats, :governism_pct, :cohesion, keyword_init: true)

  # PT grande, REDE pequena no mesmo ponto (dentro do PT), PV ao lado, encostada no PT
  # (2 pontos de governismo ≈ 13 unidades) e NOVO longe de todos
  def rows
    [
      Row.new(label: "PT", seats: 64, governism_pct: 98, cohesion: 95),
      Row.new(label: "REDE", seats: 3, governism_pct: 98, cohesion: 95),
      Row.new(label: "PV", seats: 6, governism_pct: 94, cohesion: 95),
      Row.new(label: "NOVO", seats: 5, governism_pct: 10, cohesion: 90)
    ]
  end

  test "aponta as bolhas que se cobrem e se a menor fica dentro da maior" do
    chart = positioning_chart(rows)
    pairs = chart[:overlaps].map { |o| [o[:small].label, o[:big].label, o[:inside]] }

    assert_includes pairs, ["REDE", "PT", true]
    assert(pairs.any? { |small, big, _| small == "PV" && big == "PT" })
    assert(pairs.none? { |small, big, _| [small, big].include?("NOVO") })

    points = chart[:points].index_by { |point| point[:row].label }
    assert_includes points["PT"][:overlaps], "REDE"
    assert points["REDE"][:covering]
    assert_not points["PT"][:covering]
    assert_empty points["NOVO"][:overlaps]
  end
end
