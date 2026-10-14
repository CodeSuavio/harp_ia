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

  test "busca encontra conversas pelo título ou pelo conteúdo das mensagens" do
    by_title = users(:renata).chats.create!(title: "Gastos com Combustível")
    by_message = users(:renata).chats.create!(title: "Outra investigação")
    by_message.messages.create!(role: "assistant", content: "A cota parlamentar cobre combustível.")
    by_message.messages.create!(role: "user", content: "E o combustível de 2024?")

    assert_equal [by_title, by_message].sort, Chat.search("COMBUSTÍVEL").sort
    assert_empty Chat.search("reforma tributária")
  end

  test "busca ignora acentos no termo e no conteúdo" do
    @chat.update!(title: "Votação da PEC")
    with_message = users(:renata).chats.create!(title: "Outra investigação")
    with_message.messages.create!(role: "user", content: "Quem votou a favor da reforma tributaria?")

    assert_equal [@chat], Chat.search("votacao").to_a
    assert_equal [with_message], Chat.search("tributária").to_a
  end

  test "busca trata % e _ como texto" do
    @chat.update!(title: "Votação da PEC")

    assert_empty Chat.search("%")
  end
end
