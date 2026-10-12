module Suppliers
  # Busca o cadastro (CNAE e situação) das empresas que aparecem nas despesas e
  # ainda não estão no cache ou estão desatualizadas. Ficam de fora CPFs (pessoa
  # física), notas sem documento e passagens aéreas (companhias aéreas conhecidas).
  class FetchJob < ApplicationJob
    queue_as :default
    limits_concurrency to: 1, key: "suppliers-fetch", duration: 6.hours

    # Pausa entre chamadas para respeitar o limite da BrasilAPI
    PAUSE = 1.5
    # Espera maior quando a API responde 429
    RATE_LIMIT_PAUSE = 60

    CNPJ_DIGITS = Arel.sql("REGEXP_REPLACE(supplier_cnpj_cpf, '\\D', '', 'g')")

    def perform(limit: nil, pause: PAUSE)
      pending = self.class.pending_cnpjs
      pending = pending.first(limit) if limit

      pending.each_with_index do |cnpj, index|
        sleep(pause) if index.positive?
        lookup = CnpjLookup.new(cnpj)
        lookup.call
        sleep(RATE_LIMIT_PAUSE) if lookup.rate_limited?
      end

      pending.size
    end

    # CNPJs (14 dígitos) das despesas sem cadastro ou com cadastro antigo
    def self.pending_cnpjs
      cnpjs = Expense.where.not("expense_type LIKE ?", "PASSAGEM AÉREA%")
                     .where("LENGTH(#{CNPJ_DIGITS}) = 14")
                     .distinct.pluck(CNPJ_DIGITS)
      fresh = Supplier.where(cnpj: cnpjs).where.not(id: Supplier.stale).pluck(:cnpj)
      cnpjs - fresh
    end
  end
end
