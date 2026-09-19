class PartiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @parties = policy_scope(Party)
  end

  def show
    @party = Party.find(params[:id])
    authorize @party
  end
end
