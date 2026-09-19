class ExpensesController < ApplicationController
  def index
    @deputy = Deputy.find(params[:deputy_id])
    @expenses = @deputy.expenses
  end
end
