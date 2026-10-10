class Candidate < ApplicationRecord
  belongs_to :party
  belongs_to :current_deputy,
              class_name: 'Deputy',
              optional: true,
              foreign_key: :current_deputy_id,
              primary_key: :json_id

  has_one_attached :photo

  # Deputados em exercício candidatos em 2026 (o campo do TSE costuma vir vazio, ver #reelection?)
  scope :reelection, -> { where.not(current_deputy_id: nil).where(running_for_reelection: [true, nil]) }

  validates :name, :ballot_name, :number, presence: true
  validates :number, numericality: { only_integer: true }

  # Busca por nome, nome de urna ou sigla exata do partido (atual ou antiga),
  # para "PT" não trazer PTB, PSTU etc.
  def self.search(term)
    return all if term.blank?

    term = term.strip
    like = "%#{sanitize_sql_like(term)}%"
    party_ids = Party.where(
      "upper(label) = :t OR :t = ANY(string_to_array(upper(coalesce(former_labels, '')), ' '))",
      t: term.upcase
    ).pluck(:id)

    if party_ids.any?
      where(
        "candidates.ballot_name ILIKE :l OR candidates.name ILIKE :l OR candidates.party_id IN (:ids)",
        l: like, ids: party_ids
      )
    else
      where("candidates.ballot_name ILIKE :l OR candidates.name ILIKE :l", l: like)
    end
  end

  # O campo do TSE veio vazio; quem já é deputado em exercício está concorrendo à reeleição
  def reelection?
    running_for_reelection.nil? ? current_deputy_id.present? : running_for_reelection
  end
end
