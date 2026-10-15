# Preenche a última atividade das conversas criadas antes de last_message_at
# existir, com a data da mensagem mais recente de cada uma. Conversas sem
# mensagens continuam sem data e ficam fora de "Meus Chats".
#
# Roda depois que o callback de Message já está no ar: GREATEST mantém a data
# gravada por uma mensagem criada durante o deploy. Só escreve a coluna nova
# e pode ser executada de novo sem efeito colateral.
class BackfillChatsLastMessageAt < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE chats
      SET last_message_at = GREATEST(chats.last_message_at, latest.created_at)
      FROM (SELECT chat_id, MAX(created_at) AS created_at FROM messages GROUP BY chat_id) AS latest
      WHERE chats.id = latest.chat_id
    SQL
  end

  # A coluna é removida pela migração que a criou
  def down; end
end
