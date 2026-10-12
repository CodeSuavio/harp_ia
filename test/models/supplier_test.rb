require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "confere os dígitos verificadores do CNPJ" do
    assert Supplier.valid_cnpj?("56.031.006/0001-80")
    assert Supplier.valid_cnpj?("33937681000178")
    assert_not Supplier.valid_cnpj?("00000000000000") # documento de mentira da base
    assert_not Supplier.valid_cnpj?("12.345.678/0001-90") # dígito errado
    assert_not Supplier.valid_cnpj?("123.456.789-01") # CPF
  end

  test "situação fora de ATIVA só conta a partir da data informada" do
    supplier = Supplier.new(registration_status: "BAIXADA", registration_status_date: Date.new(2025, 2, 15))
    assert supplier.inactive_on?(Date.new(2025, 3, 1))
    assert_not supplier.inactive_on?(Date.new(2025, 2, 1))
  end

  test "sem a data da situação não dá para afirmar que estava inativa na data da nota" do
    supplier = Supplier.new(registration_status: "INAPTA", registration_status_date: nil)
    assert_not supplier.inactive_on?(Date.new(2025, 3, 1))
    assert_not Supplier.new(registration_status: "ATIVA").inactive_on?(Date.new(2025, 3, 1))
  end
end
