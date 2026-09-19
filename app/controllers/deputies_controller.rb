class DeputiesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @deputies = policy_scope(Deputy)
  end

  def show
    @deputy = Deputy.find(params[:id])
    authorize @deputy
  end
end
