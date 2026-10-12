class ChatsController < ApplicationController
  include ChatResponder

  before_action :authenticate_user!
  before_action :set_chat, only: %i[show destroy]

  def index
    @chats = policy_scope(Chat)
  end

  def show
    authorize @chat
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
    # no widget e no botão "Perguntar à Harpia", processa a primeira interação.
    #
    # O MessageProcessorService centraliza todo o fluxo:
    # - salva a pergunta do usuário e a página em que foi feita
    # - envia a pergunta para a IA
    # - salva a resposta da IA
    # - gera o título da conversa, quando necessário
    if params.dig(:message, :content).present?
      MessageProcessorService.new(
        @chat,
        params[:message][:content],
        page_path: params.dig(:message, :page_path)
      ).call
    end

    respond_with_conversation
  rescue MessageProcessorService::AIError
    # Se a IA falhar, mantém o erro técnico no backend
    # e apresenta uma mensagem amigável para o usuário.
    respond_with_conversation(error_message: AI_ERROR_MESSAGE)
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
