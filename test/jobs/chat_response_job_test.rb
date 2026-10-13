require "test_helper"
require "turbo/broadcastable/test_helper"

class ChatResponseJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActionView::RecordIdentifier

  setup do
    @chat = users(:renata).chats.create!
    @question = @chat.messages.create!(role: "user", content: "Quem é a deputada?", status: :pending)
    FakeChatbot.reply("Resposta da Harpia")
  end

  teardown { FakeChatbot.reset! }

  test "salva a resposta, gera o título e envia tudo pelo WebSocket" do
    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    assert @question.reload.answered?
    assert_equal "Resposta da Harpia", @chat.messages.find_by(role: "assistant").content
    assert_equal "Título gerado", @chat.reload.title

    targets = broadcasts.map { |stream| stream["target"] }
    assert_includes targets, dom_id(@chat, :conversation)
    assert_includes targets, dom_id(@chat, :widget)
    assert_includes targets, dom_id(@chat, :title)
    assert_includes targets, "chats_list"

    conversation = broadcasts.find { |stream| stream["target"] == dom_id(@chat, :conversation) }
    assert_includes conversation.to_html, "Resposta da Harpia"
    assert_not_includes conversation.to_html, "Estamos de olho..."
  end

  test "salva as opções sugeridas em botões" do
    FakeChatbot.reply("Posso organizar de duas formas:",
                      quick_replies: ["Deputados por estado", "Ranking dentro dos estados"])

    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    assert_equal ["Deputados por estado", "Ranking dentro dos estados"],
                 @chat.messages.find_by(role: "assistant").actions.pluck("value")
    widget = broadcasts.find { |stream| stream["target"] == dom_id(@chat, :widget) }
    assert_includes widget.to_html, "Ranking dentro dos estados"
  end

  test "pergunta fora do escopo não gera título" do
    FakeChatbot.reply("Fora do escopo", out_of_scope: true)

    ChatResponseJob.perform_now(@question)

    assert @chat.messages.find_by(role: "assistant").out_of_scope?
    assert_nil @chat.reload.title
  end

  test "falha da IA marca a pergunta e mostra o aviso nas telas abertas" do
    FakeChatbot.fail!

    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    assert @question.reload.failed?
    assert_equal 1, @chat.messages.count
    assert_includes broadcasts.first.to_html, ChatResponder::AI_ERROR_MESSAGE
  end

  test "falha ao gerar o título não desfaz a resposta" do
    FakeChatbot.fail_title!

    ChatResponseJob.perform_now(@question)

    assert @question.reload.answered?
    assert_nil @chat.reload.title
  end

  test "não responde de novo uma pergunta já respondida" do
    @question.answered!

    assert_no_difference -> { @chat.messages.count } do
      ChatResponseJob.perform_now(@question)
    end
  end
end
