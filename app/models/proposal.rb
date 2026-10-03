class Proposal < ApplicationRecord
  SOURCE_KINDS = {
    "campanha"         => "Proposta de campanha",
    "plano_executivo"  => "Plano de governo do partido",
    "programa_partido" => "Programa do partido"
  }.freeze

  belongs_to :theme
  belongs_to :party, optional: true
  belongs_to :deputy, optional: true

  has_many :proposal_polls, dependent: :delete_all
  has_many :polls, through: :proposal_polls

  validates :title, presence: true
  validates :source_kind, inclusion: { in: SOURCE_KINDS.keys }
  validate :belongs_to_deputy_or_party

  # Propostas do próprio deputado e as do partido dele (as estaduais só valem para a bancada do estado)
  scope :for_deputy, ->(deputy) {
    where(deputy_id: deputy.id).or(
      where(deputy_id: nil, party_id: deputy.party_id, state_label: [nil, deputy.state_label])
    )
  }

  def source_label
    SOURCE_KINDS[source_kind]
  end

  private

  def belongs_to_deputy_or_party
    errors.add(:base, "informe o deputado ou o partido") if deputy_id.blank? && party_id.blank?
  end
end
