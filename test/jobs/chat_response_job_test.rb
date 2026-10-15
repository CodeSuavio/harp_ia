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

  test "a resposta é a última atividade da conversa, mesmo depois de gerar o título" do
    ChatResponseJob.perform_now(@question)

    answer = @chat.messages.find_by(role: "assistant")
    assert_equal "Título gerado", @chat.reload.title
    assert_equal answer.created_at, @chat.last_message_at
  end

  test "lista de Meus Chats enviada pelo WebSocket traz a conversa respondida no topo" do
    users(:renata).chats.create!(title: "Investigação anterior")
                  .messages.create!(role: "user", content: "Pergunta", created_at: 1.hour.ago)

    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    list = broadcasts.select { |stream| stream["target"] == "chats_list" }.last.to_html
    assert_operator list.index("Título gerado"), :<, list.index("Investigação anterior")
  end

  test "falha da IA mantém a pergunta como última atividade" do
    FakeChatbot.fail!

    ChatResponseJob.perform_now(@question)

    assert_equal @question.reload.created_at, @chat.reload.last_message_at
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

  test "envia o texto parcial ao chat principal e ao widget antes da resposta completa" do
    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }
    targets = broadcasts.map { |stream| stream["target"] }

    conversation_partial = broadcasts.find { |stream| stream["target"] == dom_id(@chat, :stream_conversation) }
    widget_partial = broadcasts.find { |stream| stream["target"] == dom_id(@chat, :stream_widget) }
    assert_equal "replace", conversation_partial["action"]
    assert_equal "replace", widget_partial["action"]
    # O texto parcial mantém o id, para o próximo trecho substituí-lo
    assert_includes conversation_partial.to_html, %(id="#{dom_id(@chat, :stream_conversation)}")
    assert_includes widget_partial.to_html, %(id="#{dom_id(@chat, :stream_widget)}")
    assert_includes widget_partial.to_html, "chat-widget-assistant-message"

    # A resposta completa vem depois e substitui o texto parcial
    assert_operator targets.index(dom_id(@chat, :stream_conversation)), :<, targets.index(dom_id(@chat, :conversation))
    assert_equal 1, @chat.messages.where(role: "assistant").count
  end

  test "limita a frequência dos envios do texto parcial" do
    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    # Os pedaços chegam todos de uma vez: só o primeiro texto parcial é enviado
    assert_equal(1, broadcasts.count { |stream| stream["target"] == dom_id(@chat, :stream_conversation) })
  end

  test "falha no streaming não impede a resposta e desliga o texto parcial" do
    FakeChatbot.behavior = lambda do |stream|
      stream.call(Object.new) # pedaço que não pode ser lido
      FakeChatbot.json_pieces("Resposta da Harpia", false).each { |piece| stream.call(piece) }
      { content: "Resposta da Harpia", out_of_scope: false, actions: [] }
    end

    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }
    targets = broadcasts.map { |stream| stream["target"] }

    assert @question.reload.answered?
    assert_equal "Resposta da Harpia", @chat.messages.find_by(role: "assistant").content
    assert_not_includes targets, dom_id(@chat, :stream_conversation)
    assert_includes targets, dom_id(@chat, :conversation)
  end

  test "falha da IA no meio da resposta troca o texto parcial pelo aviso de erro" do
    FakeChatbot.fail_midway!

    broadcasts = capture_turbo_stream_broadcasts(@chat) { ChatResponseJob.perform_now(@question) }

    assert @question.reload.failed?
    assert_equal 1, @chat.messages.count
    assert(broadcasts.any? { |stream| stream["target"] == dom_id(@chat, :stream_conversation) })
    conversation = broadcasts.find { |stream| stream["target"] == dom_id(@chat, :conversation) }
    assert_includes conversation.to_html, ChatResponder::AI_ERROR_MESSAGE
    assert_not_includes conversation.to_html, "Resposta interrompida"
  end

  test "não responde de novo uma pergunta já respondida" do
    @question.answered!

    assert_no_difference -> { @chat.messages.count } do
      ChatResponseJob.perform_now(@question)
    end
  end
end
