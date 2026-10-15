class Chat < ApplicationRecord
  # Título exibido na página da conversa enquanto a IA ainda não gerou um
  DEFAULT_TITLE = "Nova Investigação".freeze

  belongs_to :user
  has_many :messages, dependent: :destroy

  # Histórico de "Meus Chats": só conversas com mensagens, da última atividade
  # mais recente para a mais antiga (last_message_at, mantida por Message).
  # O id desempata, para a ordem nunca variar entre uma consulta e outra.
  scope :in_history, -> { where.not(last_message_at: nil).order(last_message_at: :desc, id: :desc) }

  # Conversas cujo título ou alguma mensagem (pergunta ou resposta) menciona
  # o termo, para encontrar uma investigação antiga em "Meus Chats".
  # Ignora maiúsculas e acentos (extensão unaccent do PostgreSQL).
  scope :search, lambda { |query|
    like = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("unaccent(chats.title) ILIKE unaccent(:like)", like: like)
      .or(where(id: Message.where("unaccent(messages.content) ILIKE unaccent(?)", like).select(:chat_id)))
  }

  # Verdadeiro enquanto a Harpia responde a última pergunta. Nesse período o
  # formulário fica bloqueado, evitando perguntas sobrepostas na conversa.
  def awaiting_response?
    messages.where(role: "user").order(:created_at).last&.awaiting_response? || false
  end
end
