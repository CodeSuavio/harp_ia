class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:show, :destroy]

  def index
    @chats = current_user.chats
  end

  def show
    authorize @chat
    @messages = @chat.messages.order(:created_at)
    @message = Message.new
  end

  def create
    @chat = current_user.chats.new

    if @chat.save
      redirect_to @chat
    else
      redirect_to chats_path, alert: "Nao foi possivel criar a conversa."
    end
  end

  def destroy
    @chat.destroy
    redirect_to chats_path
  end

  private

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end
end
