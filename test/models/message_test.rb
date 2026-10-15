require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup { @chat = users(:renata).chats.create! }

  test "pergunta recente aguarda a resposta da Harpia" do
    question = @chat.messages.create!(role: "user", content: "Pergunta", status: :pending)

    assert question.awaiting_response?
    assert_not question.response_failed?
  end

  test "pergunta pendente há mais tempo que o limite é tratada como falha" do
    question = @chat.messages.create!(role: "user", content: "Pergunta", status: :pending,
                                      created_at: (Message::RESPONSE_TIMEOUT + 1.minute).ago)

    assert_not question.awaiting_response?
    assert question.response_failed?
  end

  test "mensagens são respondidas por padrão" do
    assert @chat.messages.create!(role: "assistant", content: "Resposta").answered?
  end

  test "conversa sem mensagens não tem última atividade" do
    assert_nil @chat.last_message_at
  end

  test "nova mensagem registra a última atividade da conversa" do
    question = @chat.messages.create!(role: "user", content: "Pergunta", status: :pending)
    assert_equal question.reload.created_at, @chat.reload.last_message_at

    answer = @chat.messages.create!(role: "assistant", content: "Resposta")
    assert_equal answer.reload.created_at, @chat.reload.last_message_at
  end

  test "mensagem criada fora de ordem não faz a última atividade voltar" do
    recent = @chat.messages.create!(role: "assistant", content: "Resposta")
    @chat.messages.create!(role: "user", content: "Pergunta", created_at: 1.minute.ago)

    assert_equal recent.reload.created_at, @chat.reload.last_message_at
  end

  test "mudança de status ou de título não altera a última atividade" do
    question = @chat.messages.create!(role: "user", content: "Pergunta", status: :pending,
                                      created_at: 1.hour.ago)
    last_activity = @chat.reload.last_message_at

    question.failed!
    @chat.update!(title: "Novo título")

    assert_equal last_activity, @chat.reload.last_message_at
  end

  test "registrar a atividade não altera o updated_at da conversa" do
    updated_at = @chat.updated_at

    @chat.messages.create!(role: "user", content: "Pergunta")

    assert_equal updated_at, @chat.reload.updated_at
  end
end
