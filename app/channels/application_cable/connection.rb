module ApplicationCable
  # Conexão WebSocket usada pelas respostas da Harpia (turbo_stream_from).
  #
  # Os canais das conversas já são assinados (só quem abriu a página da
  # conversa recebe o nome do canal); aqui garantimos também que somente
  # usuários logados abrem uma conexão.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = env["warden"].user || reject_unauthorized_connection
    end
  end
end
