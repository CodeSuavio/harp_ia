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
    assert_empty @user.chats.last.messages

    # O Turbo segue o redirect com o mesmo Accept do formulário e sem
    # Turbo-Frame: a página da conversa deve abrir, sem novo redirect.
    get response.location, headers: { "Accept" => TURBO_STREAM }

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#chat_conversation"
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

  test "widget registra a página de origem da pergunta" do
    deputy = deputies(:ana)

    post chats_path,
         params: { message: { content: "Resuma este deputado", page_path: "/deputies/#{deputy.id}" } },
         headers: { "Accept" => TURBO_STREAM, "Turbo-Frame" => ChatResponder::WIDGET_FRAME }

    chat = @user.chats.last
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

  test "Meus Chats busca pelo título e pelo que foi mencionado na conversa" do
    titled = @user.chats.create!(title: "Emendas do Orçamento")
    mentioned = @user.chats.create!(title: "Perguntas gerais")
    mentioned.messages.create!(role: "user", content: "Quanto foi gasto em emendas parlamentares?")
    @user.chats.create!(title: "Votação da reforma")

    get chats_path(q: "emendas")

    assert_select "h3", text: titled.title
    assert_select "h3", text: mentioned.title
    assert_select "h3", text: "Votação da reforma", count: 0
    assert_select "mark", text: "emendas"
    assert_select "#chats_search_results"
    assert_select "#chats_list", count: 0
  end

  test "busca sem acentos destaca o termo como está escrito na conversa" do
    chat = @user.chats.create!(title: "Perguntas gerais")
    chat.messages.create!(role: "user", content: "Como foi a votação da PEC?")

    get chats_path(q: "votacao")

    assert_select "h3", text: chat.title
    assert_select "mark", text: "votação"
  end

  test "busca em Meus Chats não mostra conversas de outros usuários" do
    other = User.create!(email: "outra@example.com", password: "senha123", first_name: "Outra", last_name: "Pessoa")
    other.chats.create!(title: "Emendas secretas")

    get chats_path(q: "emendas")

    assert_select "h3", text: "Emendas secretas", count: 0
    assert_select "p", text: /Nenhum chat menciona "emendas"/
  end

  test "Meus Chats sem busca mostra todos os chats na lista atualizada pelo Turbo" do
    @user.chats.create!(title: "Emendas do Orçamento")

    get chats_path

    assert_select "input#chat-search"
    assert_select "#chats_list h3", text: "Emendas do Orçamento"
  end

  private

  def question(label, text = label)
    { "type" => "question", "label" => label, "value" => text }
  end
end
