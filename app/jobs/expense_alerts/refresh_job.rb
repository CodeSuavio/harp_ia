module ExpenseAlerts
  # Recalcula e grava os alertas de gastos (ExpenseAnomalies) de todos os
  # deputados no ano. Os alertas de cada deputado são trocados numa transação,
  # então o ranking nunca vê um deputado pela metade.
  class RefreshJob < ApplicationJob
    queue_as :maintenance
    limits_concurrency to: 1, key: ->(year) { "expense-alerts-#{year}" }

    # Recálculo de todos os anos com despesas (fim do Suppliers::FetchJob, agendamento)
    def self.refresh_all_later = years.each { |year| perform_later(year) }
    def self.refresh_all_now = years.each { |year| perform_now(year) }
    def self.years = Expense.distinct.pluck(:year)

    def perform(year)
      deputy_ids = Expense.where(year: year).distinct.pluck(:deputy_id)
      ExpenseAlert.where(year: year).where.not(deputy_id: deputy_ids).delete_all

      Deputy.where(id: deputy_ids).find_each { |deputy| refresh(deputy, year) }
    end

    private

    def refresh(deputy, year)
      now = Time.current
      records = ExpenseAnomalies.new(deputy).for_year(year).map do |row|
        ExpenseAlert.attributes_from(row).merge(deputy_id: deputy.id, year: year, created_at: now, updated_at: now)
      end

      ExpenseAlert.transaction do
        ExpenseAlert.where(deputy: deputy, year: year).delete_all
        ExpenseAlert.insert_all!(records) if records.any?
      end
    end
  end
end
