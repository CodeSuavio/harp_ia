require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup { Warden.test_mode! }
  teardown { Warden.test_reset! }

  # As respostas da Harpia são geradas em segundo plano (ChatResponseJob) e
  # chegam pelo WebSocket. No navegador, os jobs rodam de verdade, em outra
  # thread, como em produção; nos demais testes eles só são enfileirados.
  setup do
    @queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async
  end

  teardown { ActiveJob::Base.queue_adapter = @queue_adapter }
end
