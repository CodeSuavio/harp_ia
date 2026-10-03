Rails.application.routes.draw do
  devise_for :users

  # Página inicial principal
  root to: "pages#home"

  # Páginas institucionais (Sobre Nós e Contato)
  get "sobre", to: "pages#about", as: :about
  get "contato", to: "pages#contact", as: :contact

  # ==========================================
  # ÁREA PÚBLICA (Apenas Leitura)
  # ==========================================
  resources :deputies, only: [:index, :show] do
    resources :expenses, only: [:index]
  end

  resources :parties, only: [:index, :show]
  resources :bills, only: [:index, :show]
  resources :candidates, only: [:index, :show]

  resources :polls, only: [:index, :show] do
    # Rota aninhada para ver os votos de um projeto específico (/polls/:poll_id/votes)
    resources :votes, only: [:index]
  end

  # ==========================================
  # ÁREA LOGADA (Utilizadores Autenticados)
  # ==========================================
  resources :chats, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create]
  end

  # ==========================================
  # ÁREA ADMINISTRATIVA (CRUD Completo)
  # ==========================================
  # URLs geradas: /admin/deputies/new, /admin/parties/1/edit, etc.
  namespace :admin do
    resources :deputies
    resources :expenses
    resources :parties
    resources :bills
    resources :polls
    resources :votes
    resources :candidates
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
