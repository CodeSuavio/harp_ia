class ChatsController < ApplicationController
  include ChatResponder

  before_action :authenticate_user!
  before_action :set_chat, only: %i[show destroy]

  def index
    @chats = policy_scope(Chat)
    @query = params[:q].to_s.strip
    return if @query.blank?

    @chats = @chats.search(@query)
    @mentions = Message.first_mentions(@query, @chats)
  end

  def show
    authorize @chat

    # Estado atual da conversa, pedido pelo chat_controller quando a resposta
    # demora a chegar pelo WebSocket (ex.: conexão caiu no meio do caminho).
    # Enquanto a Harpia ainda responde, nada mudou: a tela não é renderizada
    # de novo, evitando saltos na rolagem da conversa.
    if request.format.turbo_stream? && turbo_frame_request?
      @chat.awaiting_response? ? head(:no_content) : respond_with_conversation
    else
      # Página da conversa. Também atende o redirect do botão "Novo Chat":
      # o Turbo segue o redirect pedindo Turbo Stream, mas sem Turbo-Frame.
      # Responder com respond_with_conversation redirecionaria para esta
      # mesma página, em loop, e a conversa nunca abriria.
      render :show, formats: :html
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
    # no widget, salva a pergunta e agenda a resposta da IA
    # (ver MessageProcessorService).
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
