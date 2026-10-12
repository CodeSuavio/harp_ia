# Cadastro de empresas fornecedoras (CNPJ) na Receita Federal, consultado na
# BrasilAPI (Suppliers::CnpjLookup) e guardado aqui para não repetir a consulta.
class Supplier < ApplicationRecord
  # Dados com mais tempo que isso são consultados de novo
  REFRESH_AFTER = 90.days
  ACTIVE = "ATIVA".freeze

  normalizes :cnpj, with: ->(cnpj) { cnpj.to_s.gsub(/\D/, "") }

  validates :cnpj, presence: true, uniqueness: true, length: { is: 14 }

  scope :stale, -> { where(fetched_at: nil).or(where(fetched_at: ...REFRESH_AFTER.ago)) }
  scope :with_activity, -> { where(fetch_error: nil).where.not(cnae_code: nil) }

  # Códigos CNAE (7 dígitos) da atividade principal e das secundárias
  def cnae_codes
    [cnae_code, *secondary_cnaes.map { |row| row["code"] }].compact_blank
  end

  # Alguma atividade começa com um dos prefixos (divisão "73", grupo "473" etc.)?
  def activity_in?(prefixes)
    cnae_codes.any? { |code| prefixes.any? { |prefix| code.start_with?(prefix) } }
  end

  # Situação cadastral diferente de ATIVA desde antes da data. Sem a data da
  # situação (ou da nota) não dá para afirmar, então devolve false
  def inactive_on?(date)
    return false if registration_status.blank? || registration_status == ACTIVE
    return false if date.nil? || registration_status_date.nil?

    registration_status_date <= date.to_date
  end

  CNPJ_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze

  # Dígitos verificadores do CNPJ conferem? Evita consultar documentos de mentira
  # que aparecem na base (ex.: 00000000000000)
  def self.valid_cnpj?(cnpj)
    digits = cnpj.to_s.gsub(/\D/, "").chars.map(&:to_i)
    return false unless digits.size == 14 && digits.uniq.size > 1

    [12, 13].all? { |size| check_digit(digits.first(size)) == digits[size] }
  end

  def self.check_digit(digits)
    rest = digits.zip(CNPJ_WEIGHTS.last(digits.size)).sum { |digit, weight| digit * weight } % 11
    rest < 2 ? 0 : 11 - rest
  end

  # 4731800 → "47.31-8/00"
  def self.format_cnae(code)
    digits = code.to_s.gsub(/\D/, "")
    return code unless digits.size == 7

    "#{digits[0, 2]}.#{digits[2, 2]}-#{digits[4]}/#{digits[5, 2]}"
  end
end
