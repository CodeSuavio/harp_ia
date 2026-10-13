# Substitui a chamada à IA nos testes de controller.
#
#   FakeChatbot.reply("Resposta")   # a IA responde com esse conteúdo
#   FakeChatbot.reply("Escolha:", quick_replies: ["A", "B"]) # com opções de escolha em botões
#   FakeChatbot.reply("Resposta", actions: [{ "type" => "link", "label" => "Ver", "value" => "/parties" }])
#   FakeChatbot.fail!               # a IA lança um erro
#   FakeChatbot.fail_title!         # responde, mas falha ao gerar o título
#   FakeChatbot.reset!              # volta ao ChatbotService real
module FakeChatbot
  mattr_accessor :behavior, :title_failure

  # delay: segundos de espera, para observar o estado "processando" nos testes de sistema
  def self.reply(content, out_of_scope: false, quick_replies: [], actions: [], delay: nil)
    choices = quick_replies.map { |text| { "type" => "question", "label" => text, "value" => text } }
    self.behavior = lambda do
      sleep(delay) if delay
      { content: content, out_of_scope: out_of_scope, actions: actions + choices }
    end
  end

  def self.fail!
    self.behavior = -> { raise "IA indisponível" }
  end

  def self.fail_title!
    self.title_failure = true
  end

  def self.reset!
    self.behavior = nil
    self.title_failure = nil
  end

  def call
    FakeChatbot.behavior ? FakeChatbot.behavior.call : super
  end

  def generate_title
    raise "IA indisponível" if FakeChatbot.title_failure

    FakeChatbot.behavior ? "Título gerado" : super
  end
end

ChatbotService.prepend(FakeChatbot)
