class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:create]

  def create
    # Cria a mensagem temporariamente para que o Pundit
    # possa verificar se o usuário tem permissão para enviá-la.
    @message = @chat.messages.new(message_params)
    @message.role = "user"

    authorize @message

    # Processa toda a interação com a IA:
    # - salva a pergunta do usuário
    # - envia a pergunta para a IA
    # - salva a resposta da IA
    # - gera o título do chat, quando necessário
    MessageProcessorService.new(
      @chat,
      message_params[:content]
    ).call

    # O mesmo endpoint atende dois fluxos:
    # HTML → chat tradicional
    # Turbo Stream → widget, sem trocar de página
    respond_to do |format|

      # Fluxo tradicional:
      # retorna para a página completa da conversa.
      format.html { redirect_to @chat }

      # Fluxo do widget:
      # atualiza somente as mensagens e o formulário
      # dentro do widget.
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "chat_widget_messages",
          partial: "chats/widget_messages"
        )
      end
    end

  rescue ActiveRecord::RecordInvalid
    redirect_to @chat,
                alert: "Nao foi possivel enviar a mensagem."
  end

  private

  def set_chat
    # Busca somente chats pertencentes ao usuário logado.
    @chat = current_user.chats.find(params[:chat_id])
  end

  def message_params
    # Permite somente o conteúdo da mensagem enviado pelo formulário.
    params.require(:message).permit(:content)
  end
end
