class DeputyOverview
  VOTE_ORDER = ["Sim", "Não", "Abstenção", "Obstrução", "Artigo 17"].freeze

  def initialize(deputy)
    @deputy = deputy
  end

  def total_spent
    @total_spent ||= expenses.sum(:net_amount)
  end

  def expense_count
    @expense_count ||= expenses.count
  end

  def average_expense
    expense_count.zero? ? 0 : total_spent / expense_count
  end

  def spent_by_year
    @spent_by_year ||= expenses.group(:year).sum(:net_amount).sort_by { |year, _| year.to_i }
  end

  def spent_by_type
    @spent_by_type ||= expenses.group(:expense_type).sum(:net_amount).sort_by { |_, total| -total }
  end

  def top_suppliers(limit = 5)
    expenses.where.not(supplier: [nil, ""])
            .group(:supplier)
            .order(Arel.sql("SUM(net_amount) DESC NULLS LAST"))
            .limit(limit)
            .pluck(:supplier, Arel.sql("SUM(net_amount)"), Arel.sql("COUNT(*)"))
  end

  def bills_count
    @bills_count ||= @deputy.bills.count
  end

  def recent_bills(limit = 5)
    @deputy.bills.order(submission_date: :desc, id: :desc).limit(limit)
  end

  def vote_breakdown
    @vote_breakdown ||= begin
      counts = @deputy.votes.group(:vote).count
      VOTE_ORDER.filter_map { |label| [label, counts[label]] if counts[label].to_i.positive? }
    end
  end

  def votes_count
    vote_breakdown.sum { |_, count| count }
  end

  def polls_voted
    @polls_voted ||= @deputy.votes.distinct.count(:poll_id)
  end

  def candidacy
    return @candidacy if defined?(@candidacy)

    @candidacy = @deputy.candidates.includes(:party).first
  end

  private

  def expenses
    @deputy.expenses
  end
end
