require "test_helper"

class SharedPaginationTest < ActionView::TestCase
  def paginate(page, total_pages)
    render partial: "shared/pagination",
           locals: { page: page, total_pages: total_pages, path_for: ->(p) { "/lista?page=#{p}" } }
  end

  test "uma página só não mostra a paginação" do
    paginate(1, 1)
    assert_select "nav", 0
  end

  test "marca a página atual e mostra a janela com reticências" do
    paginate(5, 10)
    assert_select "nav.harpia-pagination"
    assert_select ".page-item.active a[aria-current=page]", text: "5"
    assert_select ".page-link", text: "…", count: 2
    assert_select "a.page-link", text: "1"
    assert_select "a.page-link", text: "10"
    assert_select "a[rel=prev][href=?]", "/lista?page=4"
    assert_select "a[rel=next][href=?]", "/lista?page=6"
    assert_select "p", text: "Página 5 de 10"
  end

  test "na primeira página, Anterior não é link" do
    paginate(1, 3)
    assert_select ".page-item.disabled span.page-link", text: /Anterior/
    assert_select "a[rel=prev]", 0
  end

  test "na última página, Próxima não é link" do
    paginate(3, 3)
    assert_select ".page-item.disabled span.page-link", text: /Próxima/
    assert_select "a[rel=next]", 0
  end
end
