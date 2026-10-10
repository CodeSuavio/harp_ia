module PartiesHelper
  def party_tab_path(party, tab, extra = {})
    party_path(party, { tab: tab }.merge(extra.compact))
  end

  # Logo do partido: o arquivo de app/assets/images (ver Party#logo_file) ou, sem ele, o da API da Câmara
  def party_logo_path(party)
    party.logo_file ? image_path(party.logo_file) : party.logo_url.presence
  end

  # Sigla do partido com link para a página dele. Nos cartões que já são um link
  # (stretched-link), a classe party-badge fica por cima e recebe o clique
  def party_badge_link(party, css: "party-badge mt-2")
    link_to party.label, party_path(party), class: css, title: party.name, data: { turbo_frame: "_top" }
  end

  def party_logo(party, css: "party-logo")
    return unless (source = party_logo_path(party))

    image_tag source, class: css, alt: "Logo do #{party.label}", loading: "lazy"
  end

  # Opacidade do estado no mapa da bancada: vazio quase apagado, o maior estado cheio
  def bench_map_weight(seats, max_seats)
    seats.zero? ? 0.06 : 0.2 + 0.8 * seats / max_seats
  end

  # "Sim", "Não" ou "Dividida" para a maioria da bancada numa votação
  def bench_position(votes)
    DeputyMetrics.majority_of(votes[:sim], votes[:nao]) || "Dividida"
  end

  # ----- COMPARAÇÃO -----

  # Área do mapa de posicionamento, em unidades do viewBox (no topo, os rótulos das faixas)
  POSITIONING = { width: 720, height: 430, left: 52, right: 16, top: 30, bottom: 48 }.freeze
  # Largura média de um caractere do rótulo (11px, negrito) para evitar rótulos sobrepostos
  LABEL_CHAR_WIDTH = 7.2
  LABEL_HEIGHT = 12

  # { x_ticks:, y_ticks:, points: [{ row:, cx:, cy:, r:, label: { x:, y:, anchor:, inside: } | nil }] }
  # x = governismo (0 a 100%), y = coesão (do menor valor arredondado para baixo até 100%),
  # área da bolha proporcional à bancada. Rótulos que colidiriam ficam só no hover e na tabela.
  def positioning_chart(rows)
    chart = POSITIONING
    plot_w = chart[:width] - chart[:left] - chart[:right]
    plot_h = chart[:height] - chart[:top] - chart[:bottom]
    y_min = [((rows.map(&:cohesion).min.to_i - 2) / 5) * 5, 0].max
    max_seats = rows.map(&:seats).max.to_f

    x = ->(pct) { chart[:left] + plot_w * pct / 100.0 }
    y = ->(pct) { chart[:top] + plot_h * (100 - pct) / (100.0 - y_min) }

    points = rows.sort_by { |row| -row.seats }.map do |row|
      { row: row, cx: x.(row.governism_pct).round(1), cy: y.(row.cohesion).round(1),
        r: (4 + 20 * Math.sqrt(row.seats / max_seats)).round(1) }
    end
    bounds = [chart[:left], chart[:top], chart[:width] - chart[:right], chart[:top] + plot_h]
    bubbles = points.map { |p| [p[:cx] - p[:r], p[:cy] - p[:r], p[:cx] + p[:r], p[:cy] + p[:r]] }

    # Bolhas grandes escolhem primeiro: dentro da bolha (se couber, por cima das vizinhas,
    # já que os rótulos são desenhados depois) e depois ao redor dela, sem cobrir outra bolha
    labels = []
    points.each do |point|
      point[:label] = label_spots(point).find do |spot|
        box = spot[:box]
        obstacles = spot[:inside] ? labels : bubbles + labels
        inside?(box, bounds) && obstacles.none? { |other| overlap?(box, other) }
      end
      labels << point[:label][:box] if point[:label]
    end

    {
      chart: chart, plot_w: plot_w, plot_h: plot_h,
      x_ticks: (0..100).step(25).map { |pct| [pct, x.(pct).round(1)] },
      y_ticks: (y_min..100).step(5).map { |pct| [pct, y.(pct).round(1)] },
      government_x: x.(PartyComparison::BLOCS[:government][:min]).round(1),
      center_x: x.(PartyComparison::BLOCS[:center][:min]).round(1),
      points: points
    }
  end

  # Fundo da célula da matriz de afinidade: azul mais forte = mais votos iguais
  def affinity_cell_style(pct)
    alpha = (0.05 + 0.85 * pct / 100.0).round(2)
    "background-color: rgba(28, 59, 135, #{alpha}); color: #{alpha > 0.5 ? '#fff' : 'inherit'}"
  end

  def party_sort_link(label, key, sort, direction)
    active = key == sort
    default = PartyComparison::SORTS[key][:default]
    next_direction = active ? (direction == :desc ? :asc : :desc) : default
    arrow = { asc: "fa-arrow-up-short-wide", desc: "fa-arrow-down-wide-short" }[direction] if active
    link_to compare_parties_path(sort: key, dir: next_direction, anchor: "indicadores"),
            class: "text-reset text-decoration-none text-nowrap" do
      safe_join([label, (tag.i(class: "fa-solid #{arrow} ms-1 text-gold", aria: { hidden: true }) if arrow)].compact)
    end
  end

  # aria-sort do cabeçalho da coluna
  def party_sort_aria(key, sort, direction)
    return "none" unless key == sort

    direction == :asc ? "ascending" : "descending"
  end

  private

  # Posições candidatas do rótulo, na ordem de preferência
  def label_spots(point)
    width = point[:row].label.size * LABEL_CHAR_WIDTH
    cx, cy, r = point.values_at(:cx, :cy, :r)
    gap = r + 3
    diagonal = r * 0.7 + 2
    spots = []
    spots << [cx, cy + 4, "middle", true] if width <= 2 * r
    spots += [
      [cx + gap, cy + 4, "start"], [cx - gap, cy + 4, "end"],
      [cx, cy - gap - 2, "middle"], [cx, cy + gap + LABEL_HEIGHT - 2, "middle"],
      [cx + diagonal, cy - diagonal - 2, "start"], [cx - diagonal, cy - diagonal - 2, "end"],
      [cx + diagonal, cy + diagonal + LABEL_HEIGHT - 2, "start"], [cx - diagonal, cy + diagonal + LABEL_HEIGHT - 2, "end"]
    ]
    spots.map do |lx, ly, anchor, inside|
      left = { "start" => lx, "end" => lx - width, "middle" => lx - width / 2 }[anchor]
      { x: lx.round(1), y: ly.round(1), anchor: anchor, inside: inside, box: [left, ly - LABEL_HEIGHT + 2, left + width, ly + 2] }
    end
  end

  def inside?(box, bounds)
    box[0] >= bounds[0] && box[1] >= bounds[1] - 6 && box[2] <= bounds[2] && box[3] <= bounds[3]
  end

  def overlap?(a, b)
    a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
  end
end
