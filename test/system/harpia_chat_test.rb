require "application_system_test_case"

# Comportamento no navegador das duas formas de conversar com a Harpia:
# o chat principal (chats#show) e o chat widget.
class HarpiaChatTest < ApplicationSystemTestCase
  RANKING_ANSWER = "1. MDB — 3 deputados\n\n[Ver ranking completo](/parties/compare?dir=desc&sort=seats#indicadores)".freeze

  setup do
    @user = users(:renata)
    login_as @user
  end

  teardown { FakeChatbot.reset! }

  test "link de uma resposta do chat principal abre a página" do
    chat = @user.chats.create!
    chat.messages.create!(role: "user", content: "Quais partidos têm mais deputados?")
    chat.messages.create!(role: "assistant", content: RANKING_ANSWER)

    visit chat_path(chat)
    within("#chat_conversation") { click_link "Ver ranking completo" }

    assert_current_path "/parties/compare?dir=desc&sort=seats"
    within("#indicadores") { assert_text "Bancadas de deputados federais na Câmara dos Deputados" }
  end

  test "link de uma resposta do widget abre a página e mantém a conversa aberta" do
    FakeChatbot.reply(RANKING_ANSWER)

    visit chats_path
    find(".chat-widget-button").click
    within(".chat-widget-window") do
      fill_in "message[content]", with: "Quais partidos têm mais deputados?"
      find("button[type=submit]").click
      click_link "Ver ranking completo"
    end

    assert_current_path "/parties/compare?dir=desc&sort=seats"
    within(".chat-widget-window") { assert_text "Quais partidos têm mais deputados?" }
  end

  test "widget continua a mesma conversa depois de navegar pelo link" do
    FakeChatbot.reply(RANKING_ANSWER)

    visit chats_path
    find(".chat-widget-button").click
    within(".chat-widget-window") do
      fill_in "message[content]", with: "Quais partidos têm mais deputados?"
      find("button[type=submit]").click
      click_link "Ver ranking completo"
    end
    assert_current_path "/parties/compare?dir=desc&sort=seats"

    FakeChatbot.reply("O MDB lidera esse ranking.")
    within(".chat-widget-window") do
      fill_in "message[content]", with: "Quem lidera esse ranking?"
      find("button[type=submit]").click
      assert_text "O MDB lidera esse ranking."
    end

    chat = @user.chats.sole
    question = chat.messages.find_by(content: "Quem lidera esse ranking?")
    assert_equal 4, chat.messages.count
    assert_includes question.page_context, "ordenada por \"Cadeiras\""
  end

  test "chat principal mostra a pergunta, bloqueia novos envios e atualiza sem recarregar" do
    FakeChatbot.reply("Resposta da Harpia", delay: 1.5)
    chat = @user.chats.create!

    visit chat_path(chat)
    fill_in "message[content]", with: "Quem é a deputada?"
    find("#message_content").send_keys(:enter)

    # Enquanto a IA processa
    assert_text "Quem é a deputada?"
    assert_text "Estamos de olho..."
    assert_selector "#chat_conversation button[type=submit][disabled]"

    # Depois da resposta
    assert_text "Resposta da Harpia"
    assert_no_text "Estamos de olho..."
    assert_selector "#chat_title", text: "Título gerado"
    assert_selector "#chat_conversation button[type=submit]:not([disabled])"
    assert_equal 1, chat.messages.where(role: "user").count
  end

  test "chat principal mostra aviso amigável quando a IA falha" do
    FakeChatbot.fail!
    chat = @user.chats.create!

    visit chat_path(chat)
    fill_in "message[content]", with: "Pergunta"
    find("#chat_conversation button[type=submit]").click

    assert_selector ".assistant-message--error", text: ChatResponder::AI_ERROR_MESSAGE
  end
end
