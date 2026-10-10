class DeputiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show, :compare]

  PER_PAGE = 24
  TAB_PER_PAGE = 20
  COMPARE_LIMIT = 3
  TABS = {
    "overview"  => "Visão geral",
    "expenses"  => "Gastos",
    "bills"     => "Projetos de lei",
    "votes"     => "Votações",
    "promises"  => "Promessas × Atuação",
    "elections" => "Eleições 2026"
  }.freeze
  # Chaves antigas (em português) de links já compartilhados
  LEGACY_TABS = {
    "geral" => "overview", "gastos" => "expenses", "projetos" => "bills",
    "votacoes" => "votes", "promessas" => "promises", "eleicoes" => "elections"
  }.freeze
  AGAINST_PARTY = "against_party".freeze

  BILLS_COUNT_SQL = "(SELECT COUNT(*) FROM bills WHERE bills.deputy_id = deputies.id)".freeze
  # Ordenações por SQL ou por indicador calculado (DeputyMetrics), ordenadas em Ruby
  SORTS = {
    "name"          => { label: "Ordenar por nome",            order: "deputies.name ASC" },
    "state"         => { label: "Ordenar por estado",          order: "deputies.state_label ASC, deputies.name ASC" },
    "party"         => { label: "Ordenar por partido",         order: "parties.label ASC, deputies.name ASC" },
    "expenses"      => { label: "Maior gasto mensal",          metric: :monthly_expense_values },
    "bills"         => { label: "Mais projetos de lei",        order: "#{BILLS_COUNT_SQL} DESC, deputies.name ASC" },
    "participation" => { label: "Maior participação",          metric: :participation_values },
    "alignment"     => { label: "Mais alinhado ao partido",    metric: :alignment_values },
    "against_party" => { label: "Mais votos contra o partido", metric: :against_party_values }
  }.freeze

  # Termos genéricos que aparecem em quase toda indexação de projeto de lei
  GENERIC_KEYWORDS = %w[
    alteração criação normas critérios autorização obrigatoriedade proibição inclusão regulamentação
    lei código dispõe ampliação prazo requisito exigência definição diretrizes instituição política nacional
    programa fixação concessão previsão
  ].freeze

  def index
    base = apply_search(policy_scope(Deputy))

    filters = {
      state_label:      params[:state].presence,
      party_id:         params[:party].presence,
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
    @total = scope.count
    @total_pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)

    @expense_year = DeputyMetrics.reference_year
    @expenses = DeputyMetrics.expenses(@expense_year)
    @participation = DeputyMetrics.participation
    @summary = summarize(scope.pluck(:id))

    @deputies = page_of(scope)
    ids = @deputies.map(&:id)
    @bill_counts = Bill.where(deputy_id: ids).group(:deputy_id).count
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

    ids = Array(params[:ids]).reject(&:blank?).first(COMPARE_LIMIT)
    @deputies = Deputy.includes(:party, photo_attachment: :blob).where(id: ids).index_by { |d| d.id.to_s }.values_at(*ids).compact
    @comparison = DeputyComparison.new(@deputies)
  end

  private

  # ----- ABAS DO PERFIL -----

  def load_overview
    @expense_year = @deputy.expenses.maximum(:year)
    @total_expenses = @stats.total_expenses(year: @expense_year)
    @participation = @stats.vote_participation
    @alignment = @stats.party_alignment
    @bills_count = @deputy.bills.count
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
    @anomaly_expense_ids = @anomalies.flat_map { |row| row[:expense_ids].to_a }.to_set
    @anomaly_documents = expenses.where(id: @anomaly_expense_ids.to_a).where.not(document_url: [nil, ""])
                                 .pluck(:id, :document_url).to_h
    @monthly = expenses.group(:month).sum(:net_amount)
    @by_type = @stats.expenses_by_type(year: @year)
    @top_suppliers = expenses.group(Expense::SUPPLIER_KEY)
                             .order(Arel.sql("SUM(net_amount) DESC"))
                             .limit(10)
                             .pluck(Expense::SUPPLIER_NAME, Arel.sql("MAX(supplier_cnpj_cpf)"),
                                    Arel.sql("SUM(net_amount)"), Arel.sql("COUNT(*)"))

    @expense_type = params[:expense_type].presence
    @month = params[:month].presence&.to_i
    rows = expenses
    rows = rows.where(expense_type: @expense_type) if @expense_type
    rows = rows.where(month: @month) if @month
    @expenses = paginate(rows.order(document_date: :desc, id: :desc))
  end

  def load_bills
    all_bills = @deputy.bills
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
      values = send(sort[:metric])
      ordered = scope.pluck(:id, :name)
                     .sort_by { |id, name| [values[id] ? 0 : 1, -values[id].to_f, name] }
                     .map(&:first)
      page_ids = ordered.slice(offset, PER_PAGE) || []
      Deputy.includes(:party).where(id: page_ids).index_by(&:id).values_at(*page_ids)
    else
      scope.includes(:party).references(:party)
           .order(Arel.sql(sort[:order]))
           .offset(offset).limit(PER_PAGE).to_a
    end
  end

  def monthly_expense_values = @expenses.transform_values { |row| row[:monthly] }
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
