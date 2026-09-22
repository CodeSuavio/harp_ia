class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @candidates = policy_scope(Candidate).includes(:party).order(:ballot_name)
    @states = @candidates.map(&:state_label).compact.uniq.sort
  end
end
