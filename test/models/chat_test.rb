require "test_helper"

class ChatTest < ActiveSupport::TestCase
  setup { @chat = users(:renata).chats.create! }

  test "aguarda resposta somente enquanto a última pergunta está pendente" do
    assert_not @chat.awaiting_response?

    question = @chat.messages.create!(role: "user", content: "Pergunta", status: :pending)
    assert @chat.awaiting_response?

    question.answered!
    assert_not @chat.awaiting_response?
  end
end
