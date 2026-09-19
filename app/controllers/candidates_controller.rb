class CandidatesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @candidates = policy_scope(Candidate)
  end

  def show
    @candidate = Candidate.find(params[:id])
    authorize @candidate
  end
end
