class DirectoryMetrics
  attr_reader :total_polls, :max_expense

  def initialize(deputies)
    ids = deputies.map(&:id)
    @spent = Expense.where(deputy_id: ids).group(:deputy_id).sum(:net_amount)
    @votes = Vote.where(deputy_id: ids).group(:deputy_id).count
    @bills = Bill.where(deputy_id: ids).group(:deputy_id).count
    @max_expense = Rails.cache.fetch("directory_metrics/max_expense", expires_in: 10.minutes) do
      Expense.group(:deputy_id).sum(:net_amount).values.max.to_f
    end
    @total_polls = Rails.cache.fetch("directory_metrics/total_polls", expires_in: 10.minutes) do
      Vote.distinct.count(:poll_id)
    end
  end

  def spent(deputy)
    @spent[deputy.id]
  end

  def votes(deputy)
    @votes[deputy.id].to_i
  end

  def bills(deputy)
    @bills[deputy.id].to_i
  end

  def participation(deputy)
    return nil unless total_polls.positive?

    (votes(deputy) * 100.0 / total_polls).round
  end

  def expense_percent(value)
    return 0 unless max_expense.positive?

    [(value.to_f / max_expense * 100).round, 0].max
  end
end
