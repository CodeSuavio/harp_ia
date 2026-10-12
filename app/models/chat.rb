class Chat < ApplicationRecord
  # Título exibido na página da conversa enquanto a IA ainda não gerou um
  DEFAULT_TITLE = "Nova Investigação".freeze

  belongs_to :user
  has_many :messages, dependent: :destroy

  # Verdadeiro enquanto a Harpia responde a última pergunta. Nesse período o
  # formulário fica bloqueado, evitando perguntas sobrepostas na conversa.
  def awaiting_response?
    messages.where(role: "user").order(:created_at).last&.awaiting_response? || false
  end
end
