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

  after_create :register_chat_activity

  # Primeira mensagem de cada conversa que menciona o termo, por chat_id.
  # Mostrada em "Meus Chats" para explicar por que a conversa apareceu na busca.
  def self.first_mentions(query, chats)
    select("DISTINCT ON (messages.chat_id) messages.chat_id, messages.content")
      .where(chat_id: chats.select(:id))
      .where("unaccent(messages.content) ILIKE unaccent(?)", "%#{sanitize_sql_like(query.to_s.strip)}%")
      .order(:chat_id, :created_at)
      .to_h { |message| [message.chat_id, message.content] }
  end

  def awaiting_response?
    pending? && created_at > RESPONSE_TIMEOUT.ago
  end

  def response_failed?
    failed? || (pending? && !awaiting_response?)
  end

  private

  # Última atividade da conversa, usada para ordenar "Meus Chats".
  # Roda na mesma transação da criação: a mensagem nunca existe sem a data.
  # Só a criação conta; mudanças de status ou de título não reordenam.
  # GREATEST garante que a data só avança, mesmo quando uma pergunta e uma
  # resposta são criadas ao mesmo tempo (o UPDATE trava a linha do chat).
  def register_chat_activity
    Chat.where(id: chat_id).update_all(["last_message_at = GREATEST(last_message_at, ?)", created_at])
  end
end
