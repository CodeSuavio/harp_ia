# Texto da resposta da Harpia enquanto ela é gerada (streaming).
#
# A IA responde em JSON (ChatbotService::RESPONSE_SCHEMA) e envia esse JSON
# em pedaços. Esta classe junta os pedaços e extrai o valor, ainda
# incompleto, do campo "content", que vem primeiro: o OpenAI gera os campos
# na ordem do schema. Se o JSON não começar por "content", não há texto
# parcial, e a resposta aparece inteira no final, como sem streaming.
#
#   streamed = StreamedContent.new
#   streamed << '{"content":"Olá, '
#   streamed.text # => "Olá, "
class StreamedContent
  CONTENT_START = /\A\s*\{\s*"content"\s*:\s*"/

  # Escapes que chegaram pela metade no último pedaço: "\u00" sem todos os
  # dígitos, ou só a primeira metade de um emoji ("\ud83d" sem a segunda)
  INCOMPLETE_UNICODE = /\\u\h{0,3}\z|\\u[dD][89abAB]\h{2}\z/

  def initialize
    reset
  end

  def <<(piece)
    @json << piece
    self
  end

  # Nova rodada da IA (depois de consultar as ferramentas): o JSON recomeça
  def reset
    @json = +""
  end

  # Texto de "content" recebido até agora, ou nil quando ainda não há texto
  # (ou quando o trecho não pôde ser lido; o próximo pedaço tenta de novo)
  def text
    start = CONTENT_START.match(@json)
    return unless start

    JSON.parse(%("#{string_body(@json[start.end(0)..])}")).presence
  rescue JSON::ParserError
    nil
  end

  private

  # Conteúdo da string até as aspas que a fecham, sem um escape incompleto no fim
  def string_body(raw)
    escaped = false

    raw.each_char.with_index do |char, index|
      return raw[0...index] if char == '"' && !escaped

      escaped = char == "\\" && !escaped
    end

    raw = raw.chop if escaped
    raw.sub(INCOMPLETE_UNICODE, "")
  end
end
