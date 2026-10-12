class MessagesController < ApplicationController
  include ChatResponder

  before_action :authenticate_user!
  before_action :set_chat, only: [:create]

  def create
    # Cria uma mensagem temporária apenas para que o Pundit
    # possa verificar se o usuário tem permissão para enviá-la.
    #
    # A mensagem é criada diretamente com Message.new para evitar
    # adicioná-la à coleção @chat.messages antes de ser salva.
    # O salvamento real da mensagem será feito pelo MessageProcessorService.
    @message = Message.new(
      chat: @chat,
      content: message_params[:content],
      role: "user"
    )

    authorize @message

    # Uma pergunta por vez: enquanto a Harpia responde, o formulário fica
    # bloqueado na tela, e esta verificação cobre outra aba com a mesma conversa.
    return respond_with_conversation(error_message: BUSY_MESSAGE) if @chat.awaiting_response?

    # Salva a pergunta do usuário e a página em que foi feita e agenda a
    # resposta da IA (ChatResponseJob), que chega depois pelo WebSocket.
    MessageProcessorService.new(
      @chat,
      message_params[:content],
      page_path: message_params[:page_path]
    ).call

    # Atualiza o chat principal ou o widget, conforme a origem do envio,
    # mostrando a pergunta e o aviso de que a Harpia está respondendo.
    respond_with_conversation
  rescue ActiveRecord::RecordInvalid
    respond_with_conversation(error_message: INVALID_MESSAGE)
  end

  private

  def set_chat
    # Busca somente chats pertencentes ao usuário logado.
    @chat = current_user.chats.find(params[:chat_id])
  end

  def message_params
    # Permite o conteúdo da mensagem e a página em que o usuário está.
    params.require(:message).permit(:content, :page_path)
  end
end
