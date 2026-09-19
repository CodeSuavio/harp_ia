class BillsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    @bills = policy_scope(Bill)
  end

  def show
    @bill = Bill.find(params[:id])
    authorize @bill
  end
end
