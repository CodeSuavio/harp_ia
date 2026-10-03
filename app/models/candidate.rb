class Candidate < ApplicationRecord
  belongs_to :party
  belongs_to :current_deputy,
              class_name: 'Deputy',
              optional: true,
              foreign_key: :current_deputy_id,
              primary_key: :json_id


  validates :name, :ballot_name, :number, presence: true
  validates :number, numericality: { only_integer: true }

  # O campo do TSE veio vazio; quem já é deputado em exercício está concorrendo à reeleição
  def reelection?
    running_for_reelection.nil? ? current_deputy_id.present? : running_for_reelection
  end
end
