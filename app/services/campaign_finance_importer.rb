require "zlib"

# Grava os votos e a prestação de contas de 2026 dos candidatos a partir do
# db/seed_data/campanhas_2026.json.gz, gerado dos dados abertos do TSE
# (votacao_candidato_munzona_2026 e prestacao_de_contas_eleitorais_candidatos_2026).
#
# Cada linha traz o sq_candidato e os totais já agregados: votos do 1º turno somados
# por município/zona; despesas contratadas e receitas da prestação de contas mais
# recente do candidato (cada prestação parcial repete as anteriores).
class CampaignFinanceImporter
  DEFAULT_PATH = Rails.root.join("db/seed_data/campanhas_2026.json.gz")

  PUBLIC_SOURCES = ["FUNDO ESPECIAL", "FUNDO PARTIDARIO", "FUNDO PARTIDÁRIO"].freeze
  OWN_ORIGIN = "Recursos próprios"
  INDIVIDUAL_ORIGIN = "Recursos de pessoas físicas"

  def initialize(rows = nil, path: DEFAULT_PATH)
    @rows = rows || JSON.parse(Zlib::GzipReader.open(path, &:read))
  end

  def call
    candidates = Candidate.where(electoral_id: @rows.map { |row| row["sq_candidato"].to_s }).pluck(:electoral_id, :id).to_h
    now = Time.current
    records = @rows.filter_map do |row|
      candidate_id = candidates[row["sq_candidato"].to_s]
      attributes(row).merge(candidate_id: candidate_id, created_at: now, updated_at: now) if candidate_id
    end

    CampaignFinance.transaction do
      CampaignFinance.delete_all
      CampaignFinance.insert_all(records) if records.any?
    end
    { imported: records.size, skipped: @rows.size - records.size }
  end

  private

  def attributes(row)
    sources = row["receitas_por_fonte"].to_h
    origins = row["receitas_por_origem"].to_h
    {
      votes: row["votos_nominais"],
      valid_votes: row["votos_validos"],
      result: row["situacao_turno"].presence&.then { |r| r.start_with?("#") ? nil : r },
      expenses: row["despesas_contratadas"],
      expenses_count: row["qt_despesas"],
      revenues: row["receitas_total"],
      public_funds: sources.slice(*PUBLIC_SOURCES).values.sum,
      own_funds: origins[OWN_ORIGIN].to_f,
      individual_donations: origins[INDIVIDUAL_ORIGIN].to_f,
      accounts_kind: row["tipo_prestacao"],
      top_expenses: Array(row["principais_despesas"]).map { |label, value| { "label" => label, "value" => value } }
    }
  end
end
