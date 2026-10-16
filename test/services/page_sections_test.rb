require "test_helper"

# Os títulos das seções que a Harpia conhece (PageSections) são os mesmos que
# as páginas exibem: se uma view mudar um título, este teste avisa. Confere o
# texto dos templates, porque várias seções só aparecem com certos dados.
class PageSectionsTest < ActiveSupport::TestCase
  VIEWS = Rails.root.join("app/views")

  test "perfil do deputado: cada aba tem os títulos das seções" do
    DeputiesController::TABS.each_key do |tab|
      templates = ["deputies/tabs/_#{tab}", ("deputies/_party_history" if tab == "overview")]
      assert_titles PageSections::DEPUTY.fetch(tab), templates, tab
    end
  end

  test "página do partido: cada aba tem os títulos das seções" do
    PartiesController::TABS.each_key do |tab|
      assert_titles PageSections::PARTY.fetch(tab), ["parties/tabs/_#{tab}"], tab
    end
  end

  test "mapa de partidos da página inicial e da lista de partidos" do
    assert_titles PageSections::PARTY_MAP, ["parties/_overview"], "mapa"
  end

  test "funcionalidades: comparar deputados e partidos, alertas e recursos de todas as páginas" do
    assert_titles PageSections::DEPUTIES_LIST, ["deputies/index"], "lista de deputados"
    assert_titles PageSections::ALERTS, ["expense_alerts/index"], "alertas"
    assert_titles PageSections::SITE, %w[shared/_footer shared/_onboarding], "todas as páginas"
  end

  test "página da votação" do
    assert_titles PageSections::POLL, %w[polls/show polls/_dissidents polls/_states], "votação"
  end

  test "as seções da Harpia cobrem todas as abas das páginas" do
    assert_equal DeputiesController::TABS.keys.sort, (PageSections::DEPUTY.keys & DeputiesController::TABS.keys).sort
    assert_equal PartiesController::TABS.keys.sort, PageSections::PARTY.keys.sort
  end

  private

  def assert_titles(sections, templates, page)
    text = templates.compact.map { |template| VIEWS.join("#{template}.html.erb").read }.join(" ").squish
    sections.each do |id, section|
      next if section[:heading] == false

      assert_includes text, section[:title], "#{page}: #{id}"
    end
  end
end
