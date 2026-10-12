require "test_helper"

class Suppliers::FetchJobTest < ActiveJob::TestCase
  include HttpStub

  FUEL = "COMBUSTÍVEIS E LUBRIFICANTES."
  OK_BODY = { razao_social: "Posto", cnae_fiscal: 4_731_800, descricao_situacao_cadastral: "ATIVA" }.to_json

  setup do
    # CNPJs válidos; os das fixtures têm dígito verificador errado e ficam de fora
    %w[33.937.681/0001-78 56.031.006/0001-80].each do |cnpj|
      Expense.create!(deputy: deputies(:carla), year: 2025, month: 3, expense_type: FUEL, supplier: "Posto",
                      supplier_cnpj_cpf: cnpj, document_amount: 100, net_amount: 100)
    end
  end

  test "consulta em lotes, encadeia o próximo lote e recalcula os alertas no fim" do
    with_http_response(Net::HTTPOK, "200", OK_BODY) do
      assert_enqueued_with(job: Suppliers::FetchJob) { Suppliers::FetchJob.perform_now(pause: 0, batch_size: 1) }
      assert_no_enqueued_jobs(only: ExpenseAlerts::RefreshJob)
      assert_equal 1, Supplier.count

      clear_enqueued_jobs
      assert_enqueued_with(job: ExpenseAlerts::RefreshJob, args: [2025]) do
        Suppliers::FetchJob.perform_now(started_at: 1.minute.ago, fetched: 1, pause: 0, batch_size: 1)
      end
    end
    assert_equal 2, Supplier.with_activity.count
    assert_no_enqueued_jobs(only: Suppliers::FetchJob)
  end

  test "CNPJ que falhou não é tentado de novo na mesma rodada" do
    started_at = 1.minute.ago
    with_http_response(Net::HTTPGatewayTimeout, "504", "") do
      Suppliers::FetchJob.perform_now(started_at: started_at, pause: 0, batch_size: 1)
      clear_enqueued_jobs
      Suppliers::FetchJob.perform_now(started_at: started_at, fetched: 1, pause: 0, batch_size: 1)
    end

    assert_equal 2, Supplier.where.not(fetch_error: nil).count
    assert_empty Suppliers::FetchJob.pending_cnpjs(since: started_at) # rodada termina
    assert_equal 2, Suppliers::FetchJob.pending_cnpjs.size # próxima rodada tenta de novo
  end

  test "sem nada para consultar não recalcula os alertas" do
    with_http_response(Net::HTTPOK, "200", OK_BODY) { Suppliers::FetchJob.perform_now(pause: 0) }
    clear_enqueued_jobs

    assert_equal 0, Suppliers::FetchJob.perform_now(pause: 0)
    assert_no_enqueued_jobs
  end
end
