class ChatsController < ApplicationController
  include ChatResponder

  before_action :authenticate_user!
  before_action :set_chat, only: %i[show destroy]

  def index
    @chats = policy_scope(Chat)
  end

  def show
    authorize @chat

    respond_to do |format|
      format.html
      # Estado atual da conversa, pedido pelo chat_controller quando a resposta
      # demora a chegar pelo WebSocket (ex.: conexão caiu no meio do caminho).
      # Enquanto a Harpia ainda responde, nada mudou: a tela não é renderizada
      # de novo, evitando saltos na rolagem da conversa.
      format.turbo_stream do
        @chat.awaiting_response? ? head(:no_content) : respond_with_conversation
      end
    end
  end

  def create
    # Cria uma nova conversa associada ao usuário logado.
    @chat = current_user.chats.new
    authorize @chat

    unless @chat.save
      redirect_to chats_path, alert: "Nao foi possivel criar a conversa."
      return
    end

    # Quando o chat já é iniciado com uma pergunta, como acontece
    # no widget e no botão "Perguntar à Harpia", salva a pergunta e
    # agenda a resposta da IA (ver MessageProcessorService).
    if params.dig(:message, :content).present?
      MessageProcessorService.new(
        @chat,
        params[:message][:content],
        page_path: params.dig(:message, :page_path)
      ).call
    end

    respond_with_conversation
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
