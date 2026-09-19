class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:create]

  def create
    @message = @chat.messages.new(message_params)
    @message.role = "user"

    if @message.save
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
