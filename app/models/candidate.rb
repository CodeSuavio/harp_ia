class Candidate < ApplicationRecord
  belongs_to :party
  belongs_to :current_deputy, class_name: 'Deputy', optional: true

  has_many :users
end
