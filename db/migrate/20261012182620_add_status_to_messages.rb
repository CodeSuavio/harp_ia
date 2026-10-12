class AddStatusToMessages < ActiveRecord::Migration[8.1]
  # Situação da resposta a uma pergunta do usuário, agora gerada em segundo
  # plano (ChatResponseJob). As mensagens existentes já foram respondidas.
  def change
    add_column :messages, :status, :string, null: false, default: "answered"
  end
end
