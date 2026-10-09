class Party < ApplicationRecord
  # Partidos extintos por fusão ou incorporação (TSE)
  MERGERS = {
    "PSL"      => { name: "Partido Social Liberal", succeeded_by: "UNIÃO", year: 2022 },
    "DEM"      => { name: "Democratas", succeeded_by: "UNIÃO", year: 2022 },
    "PTB"      => { name: "Partido Trabalhista Brasileiro", succeeded_by: "PRD", year: 2023 },
    "PATRIOTA" => { name: "Patriota", succeeded_by: "PRD", year: 2023 },
    "PROS"     => { name: "Partido Republicano da Ordem Social", succeeded_by: "SOLIDARIEDADE", year: 2023 },
    "PSC"      => { name: "Partido Social Cristão", succeeded_by: "PODE", year: 2023 },
    "PHS"      => { name: "Partido Humanista da Solidariedade", succeeded_by: "PODE", year: 2019 },
    "PPL"      => { name: "Partido Pátria Livre", succeeded_by: "PCdoB", year: 2019 },
    "PRP"      => { name: "Partido Republicano Progressista", succeeded_by: "PATRIOTA", year: 2019 },
    "PAN"      => { name: "Partido dos Aposentados da Nação", succeeded_by: "PTB", year: 2007 },
    "PRONA"    => { name: "Partido de Reedificação da Ordem Nacional", succeeded_by: "PL", year: 2006 },
    "PGT"      => { name: "Partido Geral dos Trabalhadores", succeeded_by: "PL", year: 2003 },
    "PST"      => { name: "Partido Social Trabalhista", succeeded_by: "PL", year: 2003 }
  }.freeze

  has_many :deputies, dependent: :destroy
  has_many :candidates, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :proposals, dependent: :destroy
  has_many :poll_orientations, dependent: :nullify

  validates :name, :label, presence: true
  validates :label, uniqueness: { case_sensitive: false }

  # { sigla => { name:, year: } } dos partidos que se fundiram a este ou foram incorporados por ele
  def absorbed
    MERGERS.select { |_, merger| merger[:succeeded_by].casecmp?(label.to_s) }
           .sort_by { |sigla, merger| [-merger[:year], sigla] }.to_h
  end

  def leader
    Deputy.find_by(json_id: leader_json_id) if leader_json_id
  end
end
