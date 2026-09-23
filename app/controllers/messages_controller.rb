class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:create]

  def create
    @message = @chat.messages.new(message_params)
    @message.role = "user"

    authorize @message

    if @message.save
      llm_chat = RubyLLM.chat
      response = llm_chat.ask(@message.content)

      @chat.messages.create!(
        content: response.content,
        role: "assistant"
      )
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
