require "test_helper"

# Configuração das filas em produção (config/queue.yml e config/recurring.yml).
#
# Só as filas "harpia" e "maintenance" têm worker. A fila "default" guarda jobs
# antigos do Active Storage que não devem rodar: nenhum worker pode lê-la, nem
# usar "*". Estes testes falham se um job ou uma tarefa agendada for parar numa
# fila sem worker, onde ficaria parado em silêncio.
class QueueConfigurationTest < ActiveSupport::TestCase
  test "a Harpia e as rotinas usam filas próprias" do
    assert_equal "harpia", ChatResponseJob.queue_name
    assert_equal "maintenance", Suppliers::FetchJob.queue_name
    assert_equal "maintenance", ExpenseAlerts::RefreshJob.queue_name
    assert_equal "maintenance", ApplicationJob.queue_name
  end

  test "em produção há um worker exclusivo para cada fila e nenhum lê a default" do
    kinds = production_processes.map(&:kind)
    workers = production_processes.select { |process| process.kind == :worker }

    assert_equal %i[dispatcher worker worker], kinds
    assert_equal([["harpia"], ["maintenance"]], workers.map { |worker| Array(worker.attributes[:queues]) })
    assert_not_includes consumed_queues, "*"
    assert_not_includes consumed_queues, "default"
  end

  test "todos os jobs do projeto vão para uma fila com worker" do
    Rails.application.eager_load!

    ApplicationJob.descendants.each do |job|
      assert_includes consumed_queues, job.queue_name, "#{job} usa uma fila sem worker em produção"
    end
  end

  test "todas as tarefas agendadas vão para a fila maintenance" do
    production_recurring.each do |key, options|
      queue = options[:queue] || (options[:class] ? options[:class].constantize.queue_name : "solid_queue_recurring")

      assert_equal "maintenance", queue, "a tarefa #{key} iria para a fila #{queue}"
    end
    assert_equal %i[refresh_suppliers refresh_expense_alerts clear_solid_queue_finished_jobs], production_recurring.keys
  end

  private

  def production_processes
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/queue.yml")).deep_symbolize_keys[:production]

    SolidQueue::Configuration.new(mode: :async, standalone: false, skip_recurring: true,
                                  **config.slice(:workers, :dispatchers)).configured_processes
  end

  def consumed_queues
    production_processes.select { |process| process.kind == :worker }
                        .flat_map { |worker| Array(worker.attributes[:queues]) }
  end

  def production_recurring
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).deep_symbolize_keys[:production]
  end
end
