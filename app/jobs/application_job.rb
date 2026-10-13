class ApplicationJob < ActiveJob::Base
  # Fila padrão dos jobs do projeto. Em produção, só as filas "harpia" e
  # "maintenance" têm worker (config/queue.yml); a "default" fica sem worker e
  # pausada, guardando jobs antigos do Active Storage que não devem rodar.
  queue_as :maintenance

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
