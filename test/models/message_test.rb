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
end
