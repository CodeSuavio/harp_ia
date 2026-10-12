require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO_STREAM = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  setup do
    @user = users(:renata)
    sign_in @user
    FakeChatbot.reply("Resposta da Harpia")
  end

  teardown { FakeChatbot.reset! }

  test "botão Novo Chat abre a conversa no chat principal" do
    assert_difference -> { @user.chats.count } do
      post chats_path, headers: { "Accept" => TURBO_STREAM }
    end

    assert_redirected_to chat_path(@user.chats.last)
  end

  test "widget inicia a conversa sem sair da página" do
    post chats_path,
         params: { message: { content: "Quem é a deputada?" } },
         headers: { "Accept" => TURBO_STREAM, "Turbo-Frame" => ChatResponder::WIDGET_FRAME }

    assert_select "turbo-stream[target=chat_widget_messages]"
    assert_equal 2, @user.chats.last.messages.count
  end

  test "Perguntar à Harpia registra a página de origem e abre o chat principal" do
    deputy = deputies(:ana)

    post chats_path,
         params: { message: { content: "Resuma este deputado", page_path: "/deputies/#{deputy.id}" } },
         headers: { "Accept" => TURBO_STREAM }

    chat = @user.chats.last
    assert_redirected_to chat_path(chat)
    assert_includes chat.messages.find_by(role: "user").page_context, deputy.name
  end

  test "falha da IA ao iniciar pelo chat principal mostra a pergunta e o aviso" do
    FakeChatbot.fail!
    post chats_path, params: { message: { content: "Pergunta inicial" } }

    follow_redirect!
    assert_select ".user-message", text: /Pergunta inicial/
    assert_select ".assistant-message--error", text: /#{ChatResponder::AI_ERROR_MESSAGE}/
    assert_select ".alert", count: 0
  end

  test "página da conversa destaca respostas fora do escopo" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Receita de bolo?")
    chat.messages.create!(role: "assistant", content: "Fora do escopo", out_of_scope: true)

    get chat_path(chat)

    assert_select "turbo-frame#chat_conversation [data-chat-target=messages]"
    assert_select ".assistant-message--out-of-scope", text: /Fora do escopo/
    assert_select "#chat_title", text: Chat::DEFAULT_TITLE
  end
end
