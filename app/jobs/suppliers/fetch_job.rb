module Suppliers
  # Busca o cadastro (CNAE e situação) das empresas que aparecem nas despesas e
  # ainda não estão no cache ou estão desatualizadas. Ficam de fora CPFs (pessoa
  # física), notas sem documento, passagens aéreas (companhias aéreas conhecidas)
  # e CNPJs com dígito verificador errado.
  #
  # Roda em lotes de BATCH_SIZE: cada lote termina reenfileirando o seguinte, para
  # não prender uma thread do Solid Queue por horas e sobreviver a deploys. Os
  # lotes de uma rodada compartilham `started_at`, e um CNPJ que falhou (429, 5xx,
  # rede) não é consultado de novo na mesma rodada. No fim, se algo foi consultado,
  # agenda o recálculo dos alertas de gastos, que dependem desses dados.
  class FetchJob < ApplicationJob
    queue_as :maintenance
    # Um lote leva ~5 min (200 × 1,5 s); a trava cobre lotes lentos com folga
    limits_concurrency to: 1, key: "suppliers-fetch", duration: 1.hour

    BATCH_SIZE = 200
    # Pausa entre chamadas para respeitar o limite da BrasilAPI
    PAUSE = 1.5
    # Espera maior quando a API responde 429
    RATE_LIMIT_PAUSE = 60

    def perform(started_at: Time.current, fetched: 0, pause: PAUSE, batch_size: BATCH_SIZE)
      pending = self.class.pending_cnpjs(since: started_at)
      batch = pending.first(batch_size)
      self.class.fetch(batch, pause: pause)
      fetched += batch.size

      if pending.size > batch.size
        self.class.perform_later(started_at: started_at, fetched: fetched, pause: pause, batch_size: batch_size)
      elsif fetched.positive?
        ExpenseAlerts::RefreshJob.refresh_all_later
      end
      batch.size
    end

    # Consulta os CNPJs um a um, com pausa entre as chamadas
    def self.fetch(cnpjs, pause: PAUSE)
      cnpjs.each_with_index do |cnpj, index|
        sleep(pause) if index.positive?
        lookup = CnpjLookup.new(cnpj)
        lookup.call
        sleep(RATE_LIMIT_PAUSE) if lookup.rate_limited?
      end
    end

    # CNPJs (14 dígitos válidos) das despesas sem cadastro ou com cadastro antigo.
    # `since`: ignora os já tentados desde esse momento (lotes da mesma rodada)
    def self.pending_cnpjs(since: nil)
      cnpjs = Expense.with_cnpj.where.not("expense_type LIKE ?", "PASSAGEM AÉREA%")
                     .distinct.pluck(Expense::DOCUMENT_DIGITS)
                     .select { |cnpj| Supplier.valid_cnpj?(cnpj) }
      done = Supplier.where(cnpj: cnpjs).where.not(id: Supplier.stale)
      done = done.or(Supplier.where(cnpj: cnpjs, updated_at: since..)) if since
      cnpjs - done.pluck(:cnpj)
    end
  end
end
