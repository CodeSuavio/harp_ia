require "test_helper"

# O chat principal e o chat widget usam o mesmo endpoint; o cabeçalho
# Turbo-Frame indica qual interface fez o envio.
class MessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  TURBO_STREAM = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  setup do
    @user = users(:renata)
    @chat = @user.chats.create!
    sign_in @user
    FakeChatbot.reply("Resposta da Harpia")
  end

  teardown { FakeChatbot.reset! }

  test "chat principal mostra a pergunta na hora e agenda a resposta da IA" do
    assert_enqueued_with(job: ChatResponseJob) do
      send_message("Quem é a deputada?", frame: ChatResponder::CONVERSATION_FRAME)
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=update][target=chat_conversation]"
    assert_select "turbo-stream[action=update][target=#{dom_id(@chat, :title)}]"
    assert_select "turbo-stream[target=chat_widget_messages]", count: 0
    assert_includes response.body, "Quem é a deputada?"
    assert_includes response.body, "Estamos de olho..."
    assert @chat.messages.sole.pending?
  end

  test "formulário fica bloqueado enquanto a Harpia responde" do
    send_message("Quem é a deputada?", frame: ChatResponder::CONVERSATION_FRAME)

    assert_select "[data-chat-pending][data-chat-refresh-url='#{chat_path(@chat)}']"
    assert_select "button[type=submit][disabled]"
    assert_select "textarea[disabled]"
  end

  test "não aceita outra pergunta enquanto a anterior está sendo respondida" do
    send_message("Primeira", frame: ChatResponder::CONVERSATION_FRAME)

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      send_message("Segunda", frame: ChatResponder::CONVERSATION_FRAME)
    end

    assert_includes response.body, ChatResponder::BUSY_MESSAGE
    assert_equal ["Primeira"], @chat.messages.pluck(:content)
  end

  test "widget atualiza somente o widget e a lista de chats" do
    send_message("Quem é a deputada?", frame: ChatResponder::WIDGET_FRAME)

    assert_select "turbo-stream[action=update][target=chat_widget_messages]"
    assert_select "turbo-stream[action=update][target=chats_list]"
    assert_select "turbo-stream[target=chat_conversation]", count: 0
  end

  test "as duas interfaces registram a página em que a pergunta foi feita" do
    deputy = deputies(:ana)

    [ChatResponder::CONVERSATION_FRAME, ChatResponder::WIDGET_FRAME].each do |frame|
      perform_enqueued_jobs do
        send_message("E este deputado?", frame: frame, page_path: "/deputies/#{deputy.id}")
      end

      assert_includes @chat.messages.where(role: "user").last.page_context, deputy.name
      assert_equal "/deputies/#{deputy.id}", @chat.messages.where(role: "user").last.page_path
    end
  end

  test "gráficos: o widget recebe as seções da página; o chat principal, a página da pergunta anterior" do
    perform_enqueued_jobs do
      send_message("O que esse gráfico mostra?", frame: ChatResponder::WIDGET_FRAME, page_path: "/parties/compare")
    end
    widget_question = @chat.messages.where(role: "user").last
    assert_includes ChatbotService.new(widget_question).page_instructions, PartyComparison::SECTIONS["blocs"][:title]

    send_message("Explique o mapa de posicionamento", frame: ChatResponder::CONVERSATION_FRAME,
                                                      page_path: "/chats/#{@chat.id}")
    main_question = @chat.messages.where(role: "user").last
    service = ChatbotService.new(main_question)

    # Sem página atual, nenhuma página anterior vira "atual": ela chega só no histórico,
    # e os números do gráfico vêm de party_comparison, a mesma ferramenta do widget
    assert_nil main_question.page_context
    assert_equal "[Pergunta feita na página: Comparação entre partidos]\nO que esse gráfico mostra?",
                 service.history_content(widget_question)
  end

  test "na página da própria conversa não há registro em foco" do
    send_message("Continue", frame: ChatResponder::CONVERSATION_FRAME, page_path: "/chats/#{@chat.id}")

    assert_nil @chat.messages.where(role: "user").last.page_context
    assert_nil @chat.messages.where(role: "user").last.page_path
  end

  test "pergunta vazia mostra aviso dentro da conversa" do
    send_message("", frame: ChatResponder::CONVERSATION_FRAME)

    assert_select "turbo-stream[target=chat_conversation]"
    assert_includes response.body, ChatResponder::INVALID_MESSAGE
  end

  test "envio sem Turbo redireciona e exibe o erro da IA dentro da conversa" do
    FakeChatbot.fail!
    perform_enqueued_jobs do
      post chat_messages_path(@chat), params: { message: { content: "Pergunta" } }
    end

    assert_redirected_to chat_path(@chat)
    follow_redirect!
    assert_select ".user-message", text: /Pergunta/
    assert_select ".assistant-message--error", text: /#{ChatResponder::AI_ERROR_MESSAGE}/
  end

  test "não permite enviar mensagens para o chat de outro usuário" do
    other_chat = User.create!(email: "outro@example.com", password: "senha123", first_name: "Outro", last_name: "Usuário").chats.create!

    send_message("Oi", frame: ChatResponder::CONVERSATION_FRAME, chat: other_chat)

    assert_response :not_found
    assert_empty other_chat.messages
  end

  private

  def send_message(content, frame:, page_path: nil, chat: @chat)
    post chat_messages_path(chat),
         params: { message: { content: content, page_path: page_path } },
         headers: { "Accept" => TURBO_STREAM, "Turbo-Frame" => frame }
  end
end
