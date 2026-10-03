class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:create]

  def create
    # Cria e autoriza a mensagem enviada pelo usuário
    @message = @chat.messages.new(message_params)
    @message.role = "user"

    authorize @message

    # Gera e salva a resposta da IA
    if @message.save
      chatbot = ChatbotService.new(@message)
      assistant_response = chatbot.call

      @chat.messages.create!(
        content: assistant_response,
        role: "assistant"
      )

      # Gera o título da conversa apenas na primeira interação
      if @chat.title.blank?
        @chat.update!(title: chatbot.generate_title)
      end

      redirect_to @chat
    else
      redirect_to @chat, alert: "Nao foi possivel enviar a mensagem."
    end
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
