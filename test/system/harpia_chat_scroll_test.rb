require "application_system_test_case"

# Rolagem da conversa enquanto a Harpia escreve a resposta (streaming), no
# widget e no chat principal: acompanha o texto, para quando o usuário rola
# para cima e retoma quando ele volta ao fim.
class HarpiaChatScrollTest < ApplicationSystemTestCase
  WIDGET = ".chat-widget-messages".freeze
  CONVERSATION = ".chat-messages".freeze

  # Longa o bastante para passar da área visível já nos primeiros pedaços
  LONG_ANSWER = (("Parágrafo da resposta da Harpia com bastante texto para ocupar várias linhas. " * 6) + "\n\n") * 12

  setup do
    @user = users(:renata)
    login_as @user
  end

  teardown { FakeChatbot.reset! }

  test "widget acompanha o texto, para quando o usuário rola para cima e retoma no fim" do
    FakeChatbot.reply(LONG_ANSWER, quick_replies: ["Quem mais gastou"], pause: 0.6)

    ask_in_widget
    wait_for { streaming? && metrics(WIDGET)["top"] > 300 }
    assert at_end?(WIDGET), "a conversa deveria acompanhar o texto (#{metrics(WIDGET)})"

    # Rola para cima: os próximos trechos não mexem na rolagem
    scroll_to(WIDGET, 0)
    height = metrics(WIDGET)["height"]
    wait_for { metrics(WIDGET)["height"] > height }
    assert_equal 0, metrics(WIDGET)["top"]

    # Volta ao fim: o acompanhamento recomeça no próximo trecho
    scroll_to(WIDGET, :end)
    height = metrics(WIDGET)["height"]
    wait_for { metrics(WIDGET)["height"] > height }
    assert at_end?(WIDGET), "a conversa deveria acompanhar o texto (#{metrics(WIDGET)})"

    # Resposta definitiva: continua no fim, com os botões de próximos passos visíveis
    within(".chat-widget-window") { assert_selector "button[type=submit]:not([disabled])", wait: 10 }
    assert_no_selector "[data-chat-streaming]"
    sleep 0.3
    assert at_end?(WIDGET), "a resposta definitiva não deveria mover a conversa (#{metrics(WIDGET)})"
    assert visible_in?(WIDGET, ".chat-quick-reply"), "o botão de próximo passo deveria estar visível"
  end

  test "resposta definitiva mantém a posição de quem rolou para cima, sem rolar a página" do
    FakeChatbot.reply(LONG_ANSWER, pause: 0.4)
    chat = @user.chats.create!

    visit chat_path(chat)
    watch_page_scroll
    fill_in "message[content]", with: "Pergunta"
    find("#message_content").send_keys(:enter)
    wait_for { streaming? && metrics(CONVERSATION)["top"] > 300 }

    scroll_to(CONVERSATION, 0)
    assert_selector "#chat_conversation button[type=submit]:not([disabled])", wait: 10
    sleep 0.3

    assert_equal 0, metrics(CONVERSATION)["top"]
    assert_equal 0, page.evaluate_script("window.pageScrollMoves"), "a página não deveria rolar"
  end

  test "chat principal acompanha o texto sem rolar a página" do
    FakeChatbot.reply(LONG_ANSWER, quick_replies: ["Quem mais gastou"], pause: 0.3)
    chat = @user.chats.create!

    visit chat_path(chat)
    watch_page_scroll
    fill_in "message[content]", with: "Pergunta"
    find("#message_content").send_keys(:enter)
    wait_for { streaming? && metrics(CONVERSATION)["top"] > 300 }
    assert at_end?(CONVERSATION), "a conversa deveria acompanhar o texto (#{metrics(CONVERSATION)})"

    assert_selector "#chat_conversation button[type=submit]:not([disabled])", wait: 10
    sleep 0.3

    assert at_end?(CONVERSATION), "a conversa deveria terminar no fim (#{metrics(CONVERSATION)})"
    assert visible_in?(CONVERSATION, ".chat-quick-reply"), "o botão de próximo passo deveria estar visível"
    assert_equal 0, page.evaluate_script("window.pageScrollMoves"), "a página não deveria rolar"
  end

  test "widget reaberto no meio da resposta mostra o texto mais recente" do
    FakeChatbot.reply(LONG_ANSWER, pause: 0.6)

    ask_in_widget
    wait_for { streaming? && metrics(WIDGET)["top"] > 300 }
    click_by_script(".chat-widget-close")
    sleep 0.7 # chegam outros trechos com o widget fechado

    click_by_script(".chat-widget-button")
    wait_for { at_end?(WIDGET) }
    assert streaming?, "a resposta ainda deveria estar sendo escrita"
  end

  private

  # O aviso de boas-vindas (onboarding) pode cobrir o widget
  def click_by_script(selector)
    page.execute_script("document.querySelector('#{selector}').click()")
  end

  def ask_in_widget
    visit chats_path
    find(".chat-widget-button").click
    within(".chat-widget-window") do
      fill_in "message[content]", with: "Pergunta"
      find("button[type=submit]").click
    end
  end

  def metrics(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("#{selector}")
        return { top: Math.round(box.scrollTop), height: box.scrollHeight,
                 toEnd: Math.round(box.scrollHeight - box.scrollTop - box.clientHeight) }
      })()
    JS
  end

  def at_end?(selector) = metrics(selector)["toEnd"] <= 8
  def streaming? = page.evaluate_script("!!document.querySelector('[data-chat-streaming]')")

  def scroll_to(selector, position)
    value = position == :end ? "box.scrollHeight" : position
    page.execute_script("const box = document.querySelector('#{selector}'); box.scrollTop = #{value}")
  end

  # O elemento está inteiro dentro da área visível da conversa
  def visible_in?(selector, element)
    page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("#{selector}").getBoundingClientRect()
        const item = document.querySelector("#{selector} #{element}").getBoundingClientRect()
        return item.top >= box.top && item.bottom <= box.bottom
      })()
    JS
  end

  def watch_page_scroll
    page.execute_script(<<~JS)
      window.pageScrollMoves = 0
      window.addEventListener("scroll", () => { window.pageScrollMoves++ })
    JS
  end

  def wait_for(timeout: 10)
    deadline = Time.current + timeout
    until yield
      flunk "condição não atingida em #{timeout}s" if Time.current > deadline
      sleep 0.05
    end
  end
end
