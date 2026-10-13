require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "lista numerada da continuação de um ranking mantém a numeração" do
    html = render_markdown("As posições 6 a 7:\n\n6. Ana\n7. Bruno\n")

    assert_includes html, '<ol start="6">'
  end

  test "remove scripts e atributos perigosos da resposta" do
    html = render_markdown("<script>alert(1)</script>\n\n[link](javascript:alert(1))\n\n<p onclick=\"x()\">a</p>")

    assert_not_includes html, "<script"
    assert_not_includes html, "javascript:"
    assert_not_includes html, "onclick"
  end
end
