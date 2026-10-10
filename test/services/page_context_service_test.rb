require "test_helper"

class PageContextServiceTest < ActiveSupport::TestCase
  test "descreve o perfil do deputado com a aba e o ano" do
    deputy = deputies(:ana)
    context = PageContextService.new("/deputies/#{deputy.id}?tab=expenses&year=2025").call

    assert_includes context, "Ana Souza"
    assert_includes context, "deputy_id #{deputy.id}"
    assert_includes context, "aba \"Gastos\""
    assert_includes context, "ano 2025"
  end

  test "descreve a página de uma votação" do
    poll = polls(:first)
    assert_includes PageContextService.new("/polls/#{poll.id}").call, "poll_id #{poll.id}"
  end

  test "ignora páginas sem dados, desconhecidas e caminhos externos" do
    assert_nil PageContextService.new("/chats").call
    assert_nil PageContextService.new("/nao-existe").call
    assert_nil PageContextService.new("//exemplo.com/deputies/1").call
    assert_nil PageContextService.new("https://exemplo.com").call
    assert_nil PageContextService.new(nil).call
  end
end
