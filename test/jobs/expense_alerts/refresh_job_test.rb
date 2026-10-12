require "test_helper"

class ExpenseAlerts::RefreshJobTest < ActiveJob::TestCase
  test "grava os alertas do ano e substitui os anteriores" do
    stale = ExpenseAlert.create!(deputy: deputies(:bruno), year: 2025, kind: "month_peak", severity: :low, value: 1)
    gone = ExpenseAlert.create!(deputy: deputies(:carla), year: 2025, kind: "month_peak", severity: :low, value: 1)
    other_year = ExpenseAlert.create!(deputy: deputies(:bruno), year: 2024, kind: "month_peak", severity: :low, value: 1)

    ExpenseAlerts::RefreshJob.perform_now(2025)

    assert_not ExpenseAlert.exists?(stale.id)
    assert_not ExpenseAlert.exists?(gone.id) # Carla não tem despesas em 2025
    assert ExpenseAlert.exists?(other_year.id)

    alert = deputies(:bruno).expense_alerts.find_by!(year: 2025)
    assert_equal ["atypical_note", "high", [expenses(:bruno_fuel).id]], [alert.kind, alert.severity, alert.expense_ids]
    assert_equal "COMBUSTÍVEIS E LUBRIFICANTES.", alert.details["expense_type"]
  end
end
