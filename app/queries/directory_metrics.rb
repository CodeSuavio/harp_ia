class DirectoryMetrics
  attr_reader :year

  def initialize(deputies)
    ids = deputies.map(&:id)
    @year = DeputyMetrics.reference_year
    @expenses = DeputyMetrics.expenses(@year)
    @participation = DeputyMetrics.participation
    @bills = Bill.count_by_author(ids)
    @max_monthly = @expenses.values.map { |row| row[:monthly] }.max.to_f
  end

  def monthly_expense(deputy)
    @expenses.dig(deputy.id, :monthly)
  end

  def participation(deputy)
    @participation.dig(deputy.id, :pct)
  end

  def votes(deputy)
    @participation.dig(deputy.id, :voted).to_i
  end

  def polls(deputy)
    @participation.dig(deputy.id, :total).to_i
  end

  def bills(deputy)
    @bills[deputy.id].to_i
  end

  def expense_percent(value)
    return 0 unless @max_monthly.positive?

    [(value.to_f / @max_monthly * 100).round, 0].max
  end
end
