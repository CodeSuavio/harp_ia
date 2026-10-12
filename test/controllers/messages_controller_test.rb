require "test_helper"

# O chat principal e o chat widget usam o mesmo endpoint; o cabeçalho
# Turbo-Frame indica qual interface fez o envio.
class MessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO_STREAM = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  setup do
    @user = users(:renata)
    @chat = @user.chats.create!
    sign_in @user
    FakeChatbot.reply("Resposta da Harpia")
  end

  teardown { FakeChatbot.reset! }

  test "chat principal atualiza a própria conversa e o título" do
    send_message("Quem é a deputada?", frame: ChatResponder::CONVERSATION_FRAME)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=update][target=chat_conversation]"
    assert_select "turbo-stream[action=update][target=chat_title]", text: /Título gerado/
    assert_select "turbo-stream[target=chat_widget_messages]", count: 0
    assert_includes response.body, "Resposta da Harpia"
    assert_equal "Título gerado", @chat.reload.title
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
      send_message("E este deputado?", frame: frame, page_path: "/deputies/#{deputy.id}")

      assert_includes @chat.messages.where(role: "user").last.page_context, deputy.name
    end
  end

  test "na página da própria conversa não há registro em foco" do
    send_message("Continue", frame: ChatResponder::CONVERSATION_FRAME, page_path: "/chats/#{@chat.id}")

    assert_nil @chat.messages.where(role: "user").last.page_context
  end

  test "falha da IA mostra mensagem amigável no chat principal" do
    FakeChatbot.fail!
    send_message("Pergunta", frame: ChatResponder::CONVERSATION_FRAME)

    assert_response :success
    assert_select "turbo-stream[target=chat_conversation]"
    assert_includes response.body, ChatResponder::AI_ERROR_MESSAGE
    assert_includes response.body, "Pergunta"
  end

  test "falha da IA mostra mensagem amigável no widget" do
    FakeChatbot.fail!
    send_message("Pergunta", frame: ChatResponder::WIDGET_FRAME)

    assert_select "turbo-stream[target=chat_widget_messages]"
    assert_includes response.body, ChatResponder::AI_ERROR_MESSAGE
  end

  test "pergunta vazia mostra aviso dentro da conversa" do
    send_message("", frame: ChatResponder::CONVERSATION_FRAME)

    assert_select "turbo-stream[target=chat_conversation]"
    assert_includes response.body, ChatResponder::INVALID_MESSAGE
  end

  test "envio sem Turbo redireciona e exibe o erro dentro da conversa" do
    FakeChatbot.fail!
    post chat_messages_path(@chat), params: { message: { content: "Pergunta" } }

    assert_redirected_to chat_path(@chat)
    follow_redirect!
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
