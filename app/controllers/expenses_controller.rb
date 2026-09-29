class ExpensesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @deputy = Deputy.find(params[:deputy_id])
    @expenses = policy_scope(@deputy.expenses)
  end
end
