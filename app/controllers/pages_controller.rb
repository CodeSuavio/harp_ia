class PagesController < ApplicationController
  # Adicione :about e :contact na lista de páginas públicas
  skip_before_action :authenticate_user!, only: [ :home, :about, :contact ]

  def home
    @candidates = policy_scope(Candidate).includes(:party).order(:ballot_name)
    @states = @candidates.map(&:state_label).compact.uniq.sort
  end

  def about
    # Lógica da página sobre nós (se necessário)
  end

  def contact
    # Lógica da página de contato (se necessário)
  end
end
