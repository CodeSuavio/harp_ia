class PollsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @polls = policy_scope(Poll)
  end

  def show
    @poll = Poll.find(params[:id])
    authorize @poll
  end
end
