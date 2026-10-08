class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:show, :destroy]

  def index
    @chats = policy_scope(Chat)
  end

  def show
    authorize @chat

    @messages = @chat.messages.order(:created_at)
    @message = Message.new
  end

  def create
    # Cria uma nova conversa associada ao usuário logado.
    @chat = current_user.chats.new
    authorize @chat

    if @chat.save

      # Quando o chat já é iniciado com uma pergunta, como acontece
      # no widget "Estamos de Olho", processa a primeira interação.
      #
      # O MessageProcessorService centraliza todo o fluxo:
      # - salva a pergunta do usuário
      # - envia a pergunta para a IA
      # - salva a resposta da IA
      # - gera o título da conversa, quando necessário
      if params.dig(:message, :content).present?
        MessageProcessorService.new(
          @chat,
          params[:message][:content]
        ).call
      end

      # Atualiza a lista de chats com a conversa recém-criada.
      @chats = policy_scope(Chat)

      # O mesmo endpoint atende dois fluxos:
      # HTML → chat tradicional
      # Turbo Stream → widget, sem trocar de página
      respond_to do |format|
        format.html { redirect_to @chat }

        format.turbo_stream do
          render turbo_stream: [
            # Atualiza as mensagens exibidas dentro do widget.
            turbo_stream.update(
              "chat_widget_messages",
              partial: "chats/widget_messages"
            ),

            # Atualiza a lista da página "Meus Chats".
            # Se o usuário estiver nessa página, o novo chat
            # aparecerá sem precisar atualizar o navegador.
            turbo_stream.update(
              "chats_list",
              partial: "chats/chats_list",
              locals: { chats: @chats }
            )
          ]
        end
      end

    else
      redirect_to chats_path,
                  alert: "Nao foi possivel criar a conversa."
    end
  end

  def destroy
    authorize @chat

    @chat.destroy
    redirect_to chats_path
  end

  private

  def set_chat
    # Garante que o usuário só consiga acessar os próprios chats.
    @chat = current_user.chats.find(params[:id])
  end
end
