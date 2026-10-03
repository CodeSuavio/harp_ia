class ExpensesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  # Os gastos agora vivem na aba "Gastos" do perfil do deputado
  def index
    deputy = policy_scope(Deputy).find(params[:deputy_id])
    redirect_to deputy_path(deputy, tab: "expenses"), status: :moved_permanently
  end
end
