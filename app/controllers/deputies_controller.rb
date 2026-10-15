class DeputiesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show compare]

  PER_PAGE = 24
  TAB_PER_PAGE = 20
  COMPARE_LIMIT = DeputyComparison::LIMIT
  # Linhas por página na tabela do panorama (/deputies/compare)
  PANORAMA_PER_PAGE = 50
  ALL_TABS = {
    "overview" => "Visão geral",
    "expenses" => "Gastos",
    "bills" => "Projetos de lei",
    "votes" => "Votações",
    "promises" => "Promessas × Atuação",
    "elections" => "Eleições 2026"
  }.freeze
  # Abas escondidas do perfil: o código continua no projeto (load_*, view em
  # deputies/tabs e testes com skip). Pedidas pela URL, caem na Visão geral.
  # Para reativar uma aba, tire a chave daqui (e o skip dos testes dela).
  HIDDEN_TABS = %w[promises].freeze
  TABS = ALL_TABS.except(*HIDDEN_TABS).freeze
  # Chaves antigas (em português) de links já compartilhados
  LEGACY_TABS = {
    "geral" => "overview", "gastos" => "expenses", "projetos" => "bills",
    "votacoes" => "votes", "promessas" => "promises", "eleicoes" => "elections"
  }.freeze
  AGAINST_PARTY = "against_party".freeze

  BILLS_COUNT_SQL = <<~SQL.squish.freeze
    (SELECT COUNT(*) FROM bills WHERE bills.deputy_id = deputies.id
       OR bills.id IN (SELECT bill_id FROM bill_authors WHERE bill_authors.deputy_id = deputies.id))
  SQL
  # Ordenações por SQL ou por indicador calculado (DeputyMetrics), ordenadas em Ruby.
  # Os indicadores são os mesmos do DeputyRankingTool, com os mesmos números
  # das respostas da Harpia.
  SORTS = {
    "name" => { label: "Ordenar por nome", order: "deputies.name ASC", default: :asc },
    "state" => { label: "Ordenar por estado", order: "deputies.state_label ASC, deputies.name ASC", default: :asc },
    "party" => { label: "Ordenar por partido", order: "parties.label ASC, deputies.name ASC", default: :asc },
    "expenses" => { label: "Gasto mensal", metric: :monthly_expense_values, default: :desc },
    "expenses_total" => { label: "Gasto total no ano", metric: :total_expense_values, default: :desc },
    "bills" => { label: "Projetos de lei", metric: :bill_count_values, default: :desc },
    "participation" => { label: "Participação nas votações", metric: :participation_values, default: :desc },
    "alignment" => { label: "Alinhamento ao partido", metric: :alignment_values, default: :desc },
    "against_party" => { label: "Votos contra o partido", metric: :against_party_values, default: :desc }
  }.freeze
  # Direção das ordenações por indicador
  DIRECTIONS = { "desc" => "Maior primeiro", "asc" => "Menor primeiro" }.freeze

  # Termos genéricos que aparecem em quase toda indexação de projeto de lei
  GENERIC_KEYWORDS = %w[
    alteração criação normas critérios autorização obrigatoriedade proibição inclusão regulamentação
    lei código dispõe ampliação prazo requisito exigência definição diretrizes instituição política nacional
    programa fixação concessão previsão
  ].freeze

  def index
    base = apply_search(policy_scope(Deputy))

    filters = {
      state_label: params[:state].presence,
      party_id: params[:party].presence,
      electoral_status: params[:electoral_status].presence
    }.compact

    @reelection = params[:reelection] == "1"
    @reelection_count = apply(base, filters).running_for_reelection.count
    base = base.running_for_reelection if @reelection

    scope = apply(base, filters)

    @state_counts  = apply(base, filters.except(:state_label)).group(:state_label).count
    @party_counts  = apply(base, filters.except(:party_id)).group(:party_id).count
    @status_counts = apply(base, filters.except(:electoral_status)).group(:electoral_status).count

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "name"
    @direction = DIRECTIONS.key?(params[:dir]) ? params[:dir] : "desc"
    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)

    @expense_years = Expense.distinct.pluck(:year).sort.reverse
    @expense_year = @expense_years.include?(params[:year].to_i) ? params[:year].to_i : DeputyMetrics.reference_year
    @expenses = DeputyMetrics.expenses(@expense_year)
    @participation = DeputyMetrics.participation
    @summary = summarize(scope.pluck(:id))

    @deputies = page_of(scope)
    ids = @deputies.map(&:id)
    # Autoria e coautoria, o mesmo critério da ordenação por projetos de lei
    @bill_counts = bill_counts(Deputy.where(id: ids))
    @reelection_ids = Deputy.running_for_reelection.where(id: ids).pluck(:id).to_set

    @states = Deputy.distinct.pluck(:state_label).compact.sort
    @statuses = Deputy.distinct.pluck(:electoral_status).compact.sort
    # Esconde partidos sem deputados no recorte atual (mantendo o selecionado)
    @parties = Party.where(id: @party_counts.keys + [params[:party]].compact_blank).order(:label)
  end

  def show
    @deputy = Deputy.includes(:party).find(params[:id])
    authorize @deputy

    tab = LEGACY_TABS.fetch(params[:tab], params[:tab])
    @tab = TABS.key?(tab) ? tab : "overview"
    @stats = DeputyStats.new(@deputy)
    @candidate = @deputy.candidates.first

    send("load_#{@tab}")
  end

  def compare
    authorize Deputy

    # Deputados escolhidos na listagem (?ids[]=): comparação lado a lado
    if params.key?(:ids)
      @comparison = DeputyComparison.for(params[:ids])
      @deputies = @comparison.deputies
      return render :compare_selected
    end

    @panorama = DeputyPanorama.new
    @sort = DeputyPanorama::SORTS.key?(params[:sort]) ? params[:sort] : "governism"
    @direction = %w[asc desc].include?(params[:dir]) ? params[:dir].to_sym : DeputyPanorama::SORTS[@sort][:default]
    @state = params[:state].presence_in(Deputy.distinct.pluck(:state_label))
    @party = Party.find_by(id: params[:party]) if params[:party].present?

    rows = @panorama.sorted_rows(@sort, @direction, state: @state, party_id: @party&.id)
    @filtered = rows.size
    @total_pages = [(@filtered / PANORAMA_PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @rows = rows.slice((@page - 1) * PANORAMA_PER_PAGE, PANORAMA_PER_PAGE) || []
    @positioned = @panorama.positioned
    @filter_averages = @panorama.averages(rows) if @state || @party
    @parties = Party.where(id: Deputy.select(:party_id)).order(:label)
    @states = PartiesController::STATES
  end

  private

  # ----- ABAS DO PERFIL -----

  def load_overview
    @expense_year = @deputy.expenses.maximum(:year)
    @total_expenses = @stats.total_expenses(year: @expense_year)
    @participation = @stats.vote_participation
    @alignment = @stats.party_alignment
    @bills_count = @deputy.authored_bills.count
  end

  def load_expenses
    expenses = policy_scope(@deputy.expenses)

    @years = expenses.distinct.order(year: :desc).pluck(:year)
    @year = @years.include?(params[:year].to_i) ? params[:year].to_i : @years.first
    return unless @year

    expenses = expenses.where(year: @year)

    @total_expenses = expenses.sum(:net_amount)
    @monthly_average = @stats.monthly_average(year: @year)
    @benchmarks = @stats.expense_benchmarks(year: @year)
    @quota = DeputyMetrics.quota_usage(@deputy, @year)
    @rank = DeputyMetrics.expense_rank(@deputy, @year)
    @year_over_year = @stats.year_over_year(year: @year)
    @concentration = @stats.supplier_concentration(year: @year)
    @anomalies = ExpenseAnomalies.new(@deputy).for_year(@year)
    # { expense_id => [alertas da nota] }, para a tabela não percorrer @anomalies a cada linha
    @alerts_by_expense = @anomalies.each_with_object({}) do |row, index|
      row[:expense_ids].to_a.each { |id| (index[id] ||= []) << row }
    end
    @anomaly_expense_ids = @alerts_by_expense.keys.to_set
    @anomaly_documents = expenses.where(id: @anomaly_expense_ids.to_a).where.not(document_url: [nil, ""])
                                 .pluck(:id, :document_url).to_h
    @monthly = expenses.group(:month).sum(:net_amount)
    @by_type = @stats.expenses_by_type(year: @year)
    @top_suppliers = expenses.group(Expense::SUPPLIER_KEY)
                             .order(Arel.sql("SUM(net_amount) DESC"))
                             .limit(10)
                             .pluck(Expense::SUPPLIER_NAME, Arel.sql("MAX(supplier_cnpj_cpf)"),
                                    Arel.sql("SUM(net_amount)"), Arel.sql("COUNT(*)"))

    @expenses = paginate(filtered_expenses(expenses).order(document_date: :desc, id: :desc))
    @suppliers = Supplier.where(cnpj: @expenses.map { |e| Supplier.normalize_value_for(:cnpj, e.supplier_cnpj_cpf) })
                         .index_by(&:cnpj)
  end

  # Filtros da tabela de despesas: tipo, mês (gráfico), período (mês inicial e final) e só notas com alerta
  def filtered_expenses(rows)
    read_expense_filters
    rows = rows.where(expense_type: @expense_type) if @expense_type
    rows = rows.where(month: @month) if @month
    rows = rows.where(month: (@from || 1)..(@to || 12)) if @from || @to
    rows = rows.where(id: @anomaly_expense_ids.to_a) if @alerts_only
    rows
  end

  def read_expense_filters
    @expense_type = params[:expense_type].presence
    @from, @to = expense_period
    # Mês do gráfico fora do período (só por URL montada à mão): vale o período
    month = params[:month].presence&.to_i
    @month = month if month && ((@from || 1)..(@to || 12)).cover?(month)
    @alerts_only = params[:alerts] == "1"
  end

  # [mês inicial, mês final] (nil = sem limite); invertidos são trocados
  def expense_period
    from, to = [params[:from], params[:to]].map { |month| month.to_i if month.to_i.between?(1, 12) }
    from && to && from > to ? [to, from] : [from, to]
  end

  def load_bills
    all_bills = @deputy.authored_bills
    @bills_total = all_bills.count
    @average_bills = DeputyMetrics.average_bills
    @bill_years = all_bills.distinct.order(year: :desc).pluck(:year).compact
    @top_keywords = top_keywords(all_bills)
    @themes = themes_with_counts(DeputyThemeProfile.new(@deputy).bills_by_theme)

    @bill_year = params[:year].presence&.to_i
    @theme = Theme.find_by(slug: params[:theme]) if params[:theme].present?
    @keyword = params[:keyword].presence

    bills = all_bills
    bills = bills.where(year: @bill_year) if @bill_year
    bills = bills.where(id: BillTheme.where(theme: @theme).select(:bill_id)) if @theme
    bills = bills.where("bills.keywords ILIKE ?", "%#{Bill.sanitize_sql_like(@keyword)}%") if @keyword
    @bills = paginate(bills.order(submission_date: :desc, id: :desc))
  end

  def load_votes
    @participation = @stats.vote_participation
    @alignment = @stats.party_alignment
    @vote_counts = @deputy.votes.group(:vote).count
    @against_party_ids = @stats.against_party_poll_ids
    @themes = themes_with_counts(DeputyThemeProfile.new(@deputy).votes_by_theme)

    @vote_filter = params[:vote].presence
    @theme = Theme.find_by(slug: params[:theme]) if params[:theme].present?

    votes = @deputy.votes.joins(:poll).includes(poll: :bill)
    if @vote_filter == AGAINST_PARTY
      votes = votes.where(poll_id: @against_party_ids)
    elsif @vote_filter
      votes = votes.where(vote: @vote_filter)
    end
    votes = votes.where(poll_id: PollTheme.where(theme: @theme).select(:poll_id)) if @theme
    @votes = paginate(votes.order("polls.date DESC, votes.id DESC"))
    @majorities = @stats.party_majorities(@votes.map(&:poll_id))
  end

  def load_promises
    @profile = DeputyThemeProfile.new(@deputy)
    @theme_rows = @profile.rows
    @coherence = @profile.coherence
  end

  def load_elections
  end

  def paginate(scope)
    @tab_total = scope.count
    @tab_total_pages = [(@tab_total / TAB_PER_PAGE.to_f).ceil, 1].max
    @tab_page = params[:page].to_i.clamp(1, @tab_total_pages)
    scope.offset((@tab_page - 1) * TAB_PER_PAGE).limit(TAB_PER_PAGE).to_a
  end

  # [[theme, count]] na ordem do catálogo
  def themes_with_counts(counts)
    Theme.where(id: counts.keys).map { |theme| [theme, counts[theme.id]] }
  end

  # Palavras-chave mais frequentes nos projetos do deputado, sem termos genéricos
  def top_keywords(bills, limit = 6)
    bills.pluck(:keywords)
         .flat_map { |keywords| keywords.to_s.split(",").map { |k| k.strip.delete_suffix(".") } }
         .reject { |k| k.blank? || GENERIC_KEYWORDS.include?(k.downcase) }
         .group_by(&:downcase)
         .map { |_, words| [words.first, words.size] }
         .select { |_, count| count > 1 }
         .sort_by { |word, count| [-count, word] }
         .first(limit)
  end

  # ----- LISTAGEM -----

  def page_of(scope)
    sort = SORTS[@sort]
    offset = (@page - 1) * PER_PAGE

    if sort[:metric]
      values = @sort_values = send(sort[:metric])
      sign = @direction == "asc" ? 1 : -1
      # Quem não tem o dado fica por último, nas duas direções
      ordered = scope.pluck(:id, :name)
                     .sort_by { |id, name| [values[id] ? 0 : 1, sign * values[id].to_f, name] }
                     .map(&:first)
      page_ids = ordered.slice(offset, PER_PAGE) || []
      Deputy.includes(:party).with_attached_photo.where(id: page_ids).index_by(&:id).values_at(*page_ids)
    else
      scope.includes(:party).with_attached_photo.references(:party)
           .order(Arel.sql(sort[:order]))
           .offset(offset).limit(PER_PAGE).to_a
    end
  end

  def monthly_expense_values = @expenses.transform_values { |row| row[:monthly] }
  def total_expense_values = @expenses.transform_values { |row| row[:total] }
  def bill_count_values = bill_counts(Deputy.all)
  def participation_values = @participation.transform_values { |row| row[:pct] }
  def alignment_values = DeputyMetrics.alignment.transform_values { |row| row[:pct] }
  def against_party_values = DeputyMetrics.alignment.transform_values { |row| row[:against] }

  # Resumo do recorte filtrado (todas as páginas)
  def summarize(ids)
    monthly = @expenses.values_at(*ids).compact.map { |row| row[:monthly] }
    participation = @participation.values_at(*ids).compact.filter_map { |row| row[:pct] }

    {
      monthly_expense: monthly.any? ? monthly.sum / monthly.size : nil,
      participation: participation.any? ? (participation.sum.to_f / participation.size).round : nil,
      reelection: Deputy.running_for_reelection.where(id: ids).count
    }
  end

  # { deputy_id => projetos de autoria ou coautoria }
  def bill_counts(scope)
    scope.pluck(:id, Arel.sql(BILLS_COUNT_SQL)).to_h
  end

  def apply(scope, filters)
    filters.reduce(scope) { |s, (column, value)| s.where(column => value) }
  end

  def apply_search(scope)
    return scope if params[:q].blank?

    term = params[:q].strip
    like = "%#{term}%"
    party_ids = Party.where(
      "upper(label) = :t OR upper(coalesce(former_labels, '')) LIKE :lt",
      t: term.upcase, lt: "%#{term.upcase}%"
    ).pluck(:id)

    if party_ids.any?
      scope.where("deputies.name ILIKE :l OR deputies.party_id IN (:ids)", l: like, ids: party_ids)
    else
      scope.where("deputies.name ILIKE :l", l: like)
    end
  end
end
