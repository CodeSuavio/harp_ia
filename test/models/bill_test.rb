require "test_helper"

class BillTest < ActiveSupport::TestCase
  setup do
    @coauthored = Bill.create!(deputy: deputies(:bruno), bill_number: "5678", year: 2025)
    BillAuthor.create!(bill: @coauthored, deputy: deputies(:ana))
    BillAuthor.create!(bill: bills(:ana_bill), deputy: deputies(:ana)) # autor principal também listado em bill_authors
    @imported = Bill.create!(bill_number: "9012", year: 2025) # importado da API, sem deputy_id
    BillAuthor.create!(bill: @imported, deputy: deputies(:ana))
  end

  test "authored_by inclui autoria principal e coautoria" do
    assert_equal [bills(:ana_bill), @coauthored, @imported].sort_by(&:id), deputies(:ana).authored_bills.order(:id).to_a
    assert_equal [@coauthored], deputies(:bruno).authored_bills.to_a
  end

  test "count_by_author conta cada projeto uma vez por deputado" do
    counts = Bill.count_by_author([deputies(:ana).id, deputies(:bruno).id, deputies(:carla).id])
    assert_equal({ deputies(:ana).id => 3, deputies(:bruno).id => 1 }, counts)
  end
end
