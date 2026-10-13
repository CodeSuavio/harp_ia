class Message < ApplicationRecord
  # Tempo máximo esperado para a Harpia responder. Depois disso, uma pergunta
  # ainda "pending" (ex.: o servidor reiniciou no meio do job) é exibida como
  # falha, liberando o formulário para o usuário tentar novamente.
  RESPONSE_TIMEOUT = 2.minutes

  belongs_to :chat
  validates :content, presence: true
  validates :role, inclusion: { in: %w[user assistant] }

  # Situação da resposta a uma pergunta do usuário (ChatResponseJob):
  # - pending:  a Harpia ainda está respondendo
  # - answered: a resposta foi salva (padrão, inclusive para as respostas)
  # - failed:   a IA não conseguiu responder
  enum :status, { pending: "pending", answered: "answered", failed: "failed" }, default: :answered

  def awaiting_response?
    pending? && created_at > RESPONSE_TIMEOUT.ago
  end

  def response_failed?
    failed? || (pending? && !awaiting_response?)
  end
end
