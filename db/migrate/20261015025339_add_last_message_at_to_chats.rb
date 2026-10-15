# Data da mensagem mais recente de cada conversa, mantida por Message
# (after_create), para ordenar "Meus Chats" pela última atividade.
#
# Só cria a coluna e o índice: o preenchimento das conversas existentes fica
# em uma migração separada, publicada depois que este código já estiver no ar,
# para que nenhuma mensagem criada durante o deploy fique sem data.
class AddLastMessageAtToChats < ActiveRecord::Migration[8.1]
  def change
    # add_column bloqueia a tabela até o fim da migração: se outra transação
    # estiver usando chats, falha rápido em vez de travar as requisições.
    reversible { |dir| dir.up { execute "SET LOCAL lock_timeout = '5s'" } }

    add_column :chats, :last_message_at, :datetime
    add_index :chats, %i[user_id last_message_at]
  end
end
