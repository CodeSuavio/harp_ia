require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

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

    chat = @user.chats.last
    assert_select "turbo-stream[target=chat_widget_messages]"
    assert_select "turbo-cable-stream-source", count: 1
    assert_includes response.body, "Estamos de olho..."
    assert chat.messages.sole.pending?
    assert_enqueued_with(job: ChatResponseJob, args: [chat.messages.sole])
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
    perform_enqueued_jobs { post chats_path, params: { message: { content: "Pergunta inicial" } } }

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
    assert_select "##{dom_id(chat, :title)}", text: Chat::DEFAULT_TITLE
    assert_select "turbo-cable-stream-source", count: 1
  end

  test "próximos passos da Harpia aparecem como botões só na última resposta" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Ranking por estado?")
    chat.messages.create!(role: "assistant", content: "Posso organizar de duas formas:",
                          actions: [question("Opção antiga")])
    chat.messages.create!(role: "user", content: "Opção antiga")
    chat.messages.create!(role: "assistant", content: "Os 5 partidos com mais deputados são:",
                          actions: [question("Ver mais", "Mostre as posições 6 a 10: partidos por cadeiras"),
                                    { "type" => "link", "label" => "Ver lista completa",
                                      "value" => "/parties/compare?sort=seats" }])

    get chat_path(chat)

    assert_select ".chat-quick-reply", count: 2
    assert_select "button.chat-quick-reply[data-action='chat#quickReply']" \
                  "[data-chat-reply-param='Mostre as posições 6 a 10: partidos por cadeiras']", text: "Ver mais"
    assert_select "a.chat-quick-reply--link[href='/parties/compare?sort=seats']", text: "Ver lista completa"
    assert_select ".chat-quick-reply", text: "Opção antiga", count: 0

    get chat_path(chat), headers: { "Accept" => "text/vnd.turbo-stream.html",
                                    "Turbo-Frame" => ChatResponder::WIDGET_FRAME }

    assert_includes response.body, "chat-quick-replies--widget"
  end

  def question(label, text = label)
    { "type" => "question", "label" => label, "value" => text }
  end

  test "estado atual da conversa para a tela que não recebeu a resposta pelo WebSocket" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Pergunta")
    chat.messages.create!(role: "assistant", content: "Resposta pronta")

    get chat_path(chat), headers: { "Accept" => "text/vnd.turbo-stream.html",
                                    "Turbo-Frame" => ChatResponder::WIDGET_FRAME }

    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[target=chat_widget_messages]"
    assert_includes response.body, "Resposta pronta"
    assert_not_includes response.body, "data-chat-pending"
  end

  test "consulta enquanto a Harpia responde não renderiza a conversa de novo" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Pergunta", status: :pending)

    get chat_path(chat), headers: { "Accept" => "text/vnd.turbo-stream.html",
                                    "Turbo-Frame" => ChatResponder::CONVERSATION_FRAME }

    assert_response :no_content
  end

  test "pergunta sem resposta há muito tempo aparece como falha e libera o formulário" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Pergunta", status: :pending,
                          created_at: (Message::RESPONSE_TIMEOUT + 1.minute).ago)

    get chat_path(chat)

    assert_select ".assistant-message--error", text: /#{ChatResponder::AI_ERROR_MESSAGE}/
    assert_select "#chat_conversation button[type=submit]:not([disabled])"
  end
end
