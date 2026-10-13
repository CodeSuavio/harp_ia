class PagesController < ApplicationController
  include PartyOverview

  # Adicione :about e :contact na lista de páginas públicas
  skip_before_action :authenticate_user!, only: %i[home about contact]

  def home
    load_party_overview
  end

  def about
    # Lógica da página sobre nós (se necessário)
  end

  def contact
    # Lógica da página de contato (se necessário)
  end
end
