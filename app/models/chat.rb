class Chat < ApplicationRecord
  # Título exibido na página da conversa enquanto a IA ainda não gerou um
  DEFAULT_TITLE = "Nova Investigação".freeze

  belongs_to :user
  has_many :messages, dependent: :destroy
end
