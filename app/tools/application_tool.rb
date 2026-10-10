# Base das ferramentas que a Harpia usa para consultar o banco de dados.
#
# Cada ferramenta é somente leitura e devolve apenas dados públicos da
# plataforma (nunca dados de usuários ou de outros chats). O retorno é um
# Hash que o RubyLLM envia à IA como JSON.
class ApplicationTool < RubyLLM::Tool
  LIST_LIMIT = 10

  private

  # Helpers das views, para reaproveitar os mesmos textos e caminhos das páginas
  def helpers
    ApplicationController.helpers
  end

  # Caminhos das páginas (deputy_path etc.), para a IA poder indicar onde ver mais
  def routes
    Rails.application.routes.url_helpers
  end

  def not_found(kind)
    { erro: "#{kind} não encontrado na base do Harp_IA." }
  end

  def money(value)
    value&.to_f&.round(2)
  end

  def party_label(record)
    record.party&.label
  end
end
