# Substitui a chamada à IA nos testes de controller.
#
#   FakeChatbot.reply("Resposta")   # a IA responde com esse conteúdo
#   FakeChatbot.reply("Escolha:", quick_replies: ["A", "B"]) # com opções de escolha em botões
#   FakeChatbot.reply("Resposta", actions: [{ "type" => "link", "label" => "Ver", "value" => "/parties" }])
#   FakeChatbot.reply("Resposta", records: [{ "type" => "party", "id" => 1, "name" => "PT" }]) # registros apresentados
#   FakeChatbot.reply("Resposta", pause: 0.3) # o texto chega aos poucos, com pausas entre os pedaços
#   FakeChatbot.fail!               # a IA lança um erro
#   FakeChatbot.fail_midway!        # a IA lança um erro depois de escrever parte da resposta
#   FakeChatbot.fail_title!         # responde, mas falha ao gerar o título
#   FakeChatbot.reset!              # volta ao ChatbotService real
#
# Como a IA real, a resposta chega em pedaços de JSON (streaming), que passam
# pelo mesmo tratamento do ChatbotService (StreamedContent e falhas isoladas).
module FakeChatbot
  mattr_accessor :behavior, :title_failure

  # Pedaços em que o JSON da resposta é dividido
  PIECES = 10

  # delay: segundos de espera, para observar o estado "processando" nos testes de sistema
  # pause: segundos entre os pedaços da resposta, para observar o texto parcial
  def self.reply(content, out_of_scope: false, quick_replies: [], actions: [], records: [], delay: nil, pause: nil) # rubocop:disable Metrics/ParameterLists
    choices = quick_replies.map { |text| { "type" => "question", "label" => text, "value" => text } }
    self.behavior = lambda do |stream|
      sleep(delay) if delay
      json_pieces(content, out_of_scope).each do |piece|
        stream.call(piece)
        sleep(pause) if pause
      end
      { content: content, out_of_scope: out_of_scope, actions: actions + choices, records: records }
    end
  end

  def self.fail!
    self.behavior = ->(_stream) { raise "IA indisponível" }
  end

  def self.fail_midway!
    self.behavior = lambda do |stream|
      json_pieces("Resposta interrompida no meio", false).first(PIECES / 2).each { |piece| stream.call(piece) }
      raise "IA indisponível"
    end
  end

  def self.fail_title!
    self.title_failure = true
  end

  def self.reset!
    self.behavior = nil
    self.title_failure = nil
  end

  # JSON no formato do ChatbotService::RESPONSE_SCHEMA, em pedaços
  def self.json_pieces(content, out_of_scope)
    json = { content: content, out_of_scope: out_of_scope, acoes: [], descobertas: [], quick_replies: [] }.to_json
    json.chars.each_slice((json.length / PIECES.to_f).ceil).map(&:join)
  end

  def call(&on_text)
    return super unless FakeChatbot.behavior

    FakeChatbot.behavior.call(->(piece) { stream(piece, &on_text) if on_text })
  end

  def generate_title
    raise "IA indisponível" if FakeChatbot.title_failure

    FakeChatbot.behavior ? "Título gerado" : super
  end
end

ChatbotService.prepend(FakeChatbot)
