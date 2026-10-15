require "test_helper"

class StreamedContentTest < ActiveSupport::TestCase
  def streamed(*pieces)
    pieces.each_with_object(StreamedContent.new) { |piece, content| content << piece }
  end

  test "extrai o texto parcial de content enquanto o JSON chega" do
    assert_nil streamed('{"con').text
    assert_nil streamed('{"content":"').text
    assert_equal "Olá, ", streamed('{"content":"Ol', 'á, ').text
  end

  test "para nas aspas que fecham content, sem os demais campos" do
    assert_equal "Pronto", streamed('{"content":"Pronto","out_of_scope":false,"acoes":[]}').text
  end

  test "decodifica escapes, inclusive aspas e quebras de linha" do
    assert_equal "Ele disse \"sim\"\n\n1. MDB", streamed('{"content":"Ele disse \\"sim\\"\\n\\n1. MDB"}').text
    assert_equal "C:\\", streamed('{"content":"C:\\\\').text
  end

  test "ignora um escape que chegou pela metade" do
    assert_equal "linha", streamed('{"content":"linha\\').text
    assert_equal "a", streamed('{"content":"a\\u00').text
    assert_equal "aé", streamed('{"content":"a\\u00', "e9").text
  end

  test "ignora a primeira metade de um emoji" do
    assert_equal "ok ", streamed('{"content":"ok \\ud83d').text
    assert_equal "ok 👀", streamed('{"content":"ok \\ud83d', '\\udc40').text
  end

  test "aceita espaços e quebras de linha no JSON" do
    assert_equal "Oi", streamed(%({\n  "content": "Oi)).text
  end

  test "sem texto parcial quando o JSON não começa por content" do
    assert_nil streamed('{"out_of_scope":false,"content":"Oi').text
  end

  test "recomeça a cada rodada da IA" do
    content = streamed('{"content":"Rodada anterior')
    content.reset
    content << '{"content":"Nova'

    assert_equal "Nova", content.text
  end
end
