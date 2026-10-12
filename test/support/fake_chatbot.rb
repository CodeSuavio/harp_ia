# Substitui a chamada à IA nos testes de controller.
#
#   FakeChatbot.reply("Resposta")   # a IA responde com esse conteúdo
#   FakeChatbot.fail!               # a IA lança um erro
#   FakeChatbot.reset!              # volta ao ChatbotService real
module FakeChatbot
  mattr_accessor :behavior

  # delay: segundos de espera, para observar o estado "processando" nos testes de sistema
  def self.reply(content, out_of_scope: false, delay: nil)
    self.behavior = lambda do
      sleep(delay) if delay
      { content: content, out_of_scope: out_of_scope }
    end
  end

  def self.fail!
    self.behavior = -> { raise "IA indisponível" }
  end

  def self.reset!
    self.behavior = nil
  end

  def call
    FakeChatbot.behavior ? FakeChatbot.behavior.call : super
  end

  def generate_title
    FakeChatbot.behavior ? "Título gerado" : super
  end
end

ChatbotService.prepend(FakeChatbot)
